-- The terminal deck: one centred floating window holding a row of persistent
-- shells, presented as tabs along the top border.
--
--   <leader>p        show / hide the deck (shells keep running while hidden)
--   <leader>n        new tab
--   <leader>h / l    previous / next tab
--   <leader>1..9     jump to tab N
--   <leader>x        close + kill the current tab (guarded if it is busy)
--
-- The tab keys mirror the bufferline bindings (h/l/1-9) so switching between
-- code buffers and terminal tabs feels the same.
--
-- The deck is for long-running work: hiding it with <leader>p leaves every
-- shell alive with its scrollback intact. A shell only dies when its tab is
-- closed with <leader>x, or when you type `exit` in it. This is the opposite
-- of the ephemeral <leader>t panel, which kills on close.
--
-- These terminals are toggleterm `Terminal` objects with ids from 101 up, kept
-- clear of the panel (id 1) and any :ToggleTerm {N}. toggleterm never lists
-- terminal buffers, so none of this reaches the bufferline.

local guard = require("term.guard")

local M = {}

local tabs = {} ---@type table[]  ordered list of Terminal objects
local current = 0 -- index into `tabs`; 0 when the deck is empty
local next_id = 100 -- monotonic; deck terminal ids are 101, 102, ...

-- 80% of the editor, centred, recomputed on every open and on VimResized.
local function pct(base, p)
  return function() return math.floor(vim.o[base] * p) end
end

local function define_hls()
  local green = vim.g.terminal_color_2 or vim.g.terminal_color_10 or "#6A9955"
  vim.api.nvim_set_hl(0, "TermDeckTab", { fg = "#6b6b6b" })
  vim.api.nvim_set_hl(0, "TermDeckTabSel", { fg = "#141516", bg = green, bold = true })
  vim.api.nvim_set_hl(0, "TermDeckTabNew", { fg = green })
end
define_hls()

-- Paint the tab strip into the float's border title. toggleterm rewrites the
-- title to its own `display_name` whenever it rebuilds the float (e.g. on
-- resize), so this is re-applied from on_open and from a VimResized handler.
local function render_title(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  -- one blank cell of padding at each end and between every pill
  local chunks = { { " ", "TermDeckTab" } }
  for i = 1, #tabs do
    chunks[#chunks + 1] = { (" %d "):format(i), i == current and "TermDeckTabSel" or "TermDeckTab" }
    chunks[#chunks + 1] = { " ", "TermDeckTab" }
  end
  -- "new tab": padded to the same 3-cell width as a tab pill
  chunks[#chunks + 1] = { " + ", "TermDeckTabNew" }
  chunks[#chunks + 1] = { " ", "TermDeckTab" }
  pcall(vim.api.nvim_win_set_config, win, { title = chunks, title_pos = "center" })
end

local function is_visible()
  return current >= 1 and tabs[current] and tabs[current]:is_open()
end

-- Buffer-local maps for a deck terminal. Normal mode only (press `kj` first),
-- matching the panel's style and keeping the shell's own keys untouched.
local function set_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<leader>n", function() M.new_tab() end, opts)
  vim.keymap.set("n", "<leader>l", function() M.next() end, opts)
  vim.keymap.set("n", "<leader>h", function() M.prev() end, opts)
  for i = 1, 9 do
    vim.keymap.set("n", "<leader>" .. i, function() M.go(i) end, opts)
  end
  vim.keymap.set("n", "<leader>x", function() M.close_tab() end, opts)
  -- <C-\> hides the deck too, so the panel key never opens the panel on top of it
  vim.keymap.set({ "n", "t" }, [[<C-\>]], function() M.toggle() end, opts)
end

local function new_term()
  next_id = next_id + 1
  local term = require("toggleterm.terminal").Terminal:new({
    id = next_id,
    direction = "float",
    -- kept out of toggleterm's own toggle/list heuristics; the deck drives
    -- these terminals directly by object reference.
    hidden = true,
    -- auto_scroll does `normal! G` on every output while in normal mode, which
    -- yanks the cursor off the prompt to the blank last line (e.g. when a new
    -- shell's first prompt arrives after show() has dropped to normal mode).
    auto_scroll = false,
    -- explicit centred geometry: without row/col the panel's bottom-strip
    -- coordinates would leak in through toggleterm's config merge.
    float_opts = {
      border = "rounded",
      width = pct("columns", 0.8),
      height = pct("lines", 0.8),
      row = pct("lines", 0.1),
      col = pct("columns", 0.1),
    },
    on_open = function(t)
      vim.wo[t.window].scrolloff = 0
      vim.wo[t.window].sidescrolloff = 0
      set_keymaps(t.bufnr)
      render_title(t.window)
    end,
    on_stdout = function(t)
      if not t.__awaiting_prompt then return end
      t.__awaiting_prompt = false
      local cb = t.__to_normal
      t.__to_normal = nil
      -- brief pause so a prompt that arrives in several chunks is complete
      if cb then vim.defer_fn(cb, 30) end
    end,
    on_exit = function(t)
      if t.__deck_killed then return end -- close_tab already did the bookkeeping
      M._forget(t)
    end,
  })
  term.__awaiting_prompt = true
  return term
end

-- Land in normal mode (`a`/`i` to type). toggleterm's start_in_insert is
-- global and the panel wants it, so undo it here, after both its spawn-time
-- startinsert and its scheduled TermEnter one. Go *through* terminal mode
-- and leave with a real <C-\><C-n> rather than :stopinsert: only that exit
-- puts the cursor on the shell's cursor (the prompt) instead of leaving it
-- on the last buffer line where toggleterm parked it.
local function to_normal(t)
  if tabs[current] ~= t or not t:is_focused() then return end
  vim.cmd("startinsert")
  vim.api.nvim_feedkeys(vim.keycode([[<C-\><C-n>]]), "n", false)
end

-- Show tab `idx`, hiding whichever tab is currently on screen.
local function show(idx)
  if not tabs[idx] then return end
  for i, t in ipairs(tabs) do
    if i ~= idx and t:is_open() then t:close() end
  end
  current = idx
  local t = tabs[idx]
  if t:is_open() then
    t:focus()
    render_title(t.window)
  else
    t:open() -- fires on_open -> render_title
  end
  -- Land in normal mode (see to_normal). A brand-new shell hasn't drawn its
  -- prompt yet, so leaving now would put the cursor at column 0; on_stdout
  -- calls this once the prompt arrives.
  if t.__awaiting_prompt then
    t.__to_normal = function() to_normal(t) end
  else
    vim.schedule(function() to_normal(t) end)
  end
end

-- A shell exited on its own (`exit`). Drop its tab; slide to a neighbour if the
-- deck was on screen.
function M._forget(term)
  local idx
  for i, t in ipairs(tabs) do
    if t == term then idx = i break end
  end
  if not idx then return end
  local was_visible = term:is_open() -- on_exit runs before toggleterm closes it
  table.remove(tabs, idx)
  if current > #tabs then current = #tabs end
  if #tabs == 0 then
    current = 0
    return
  end
  if was_visible then
    vim.schedule(function()
      if #tabs > 0 then show(current) end
    end)
  end
end

--- Show the deck, or hide it (leaving every shell running).
function M.toggle()
  if is_visible() then
    tabs[current]:close()
    return
  end
  if #tabs == 0 then
    tabs[1] = new_term()
    current = 1
  elseif current < 1 then
    current = 1
  end
  show(current)
end

--- Jump to tab `idx`; a no-op if it is out of range (matches bufferline).
function M.go(idx)
  if tabs[idx] then show(idx) end
end

--- Next tab, stopping at the last. Non-wrapping, like the bufferline h/l keys.
function M.next()
  if current < #tabs then show(current + 1) end
end

--- Previous tab, stopping at the first.
function M.prev()
  if current > 1 then show(current - 1) end
end

--- New shell, inserted just after the current tab and focused.
function M.new_tab()
  local t = new_term()
  if #tabs == 0 then
    tabs[1], current = t, 1
  else
    table.insert(tabs, current + 1, t)
    current = current + 1
  end
  show(current)
end

--- Close the current tab: kill its shell (guarded if a command is running) and
--- reveal a neighbour, or shut the deck if it was the last one.
function M.close_tab()
  local t = tabs[current]
  if not t then return end
  if not guard.may_kill(t.bufnr) then return end

  t.__deck_killed = true
  table.remove(tabs, current)
  if #tabs == 0 then
    current = 0
    t:shutdown()
    return
  end
  if current > #tabs then current = #tabs end
  t:shutdown()
  show(current)
end

local group = vim.api.nvim_create_augroup("TermDeck", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = vim.schedule_wrap(define_hls) })
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    if is_visible() then
      vim.schedule(function()
        if is_visible() then render_title(tabs[current].window) end
      end)
    end
  end,
})

return M
