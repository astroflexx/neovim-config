-- The terminal deck: one centred floating window holding a row of persistent
-- shells, presented as tabs along the top border.
--
--   <leader>p        show / hide the deck (shells keep running while hidden)
--   gt / gT          next / previous tab   ({count}gt jumps to tab {count})
--   <C-t>            new tab
--   <leader>x        close + kill the current tab (guarded if it is busy)
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
  local chunks = {}
  for i = 1, #tabs do
    chunks[#chunks + 1] = { (" %d "):format(i), i == current and "TermDeckTabSel" or "TermDeckTab" }
  end
  chunks[#chunks + 1] = { "  ", "TermDeckTab" }
  chunks[#chunks + 1] = { " + ", "TermDeckTabNew" }
  pcall(vim.api.nvim_win_set_config, win, { title = chunks, title_pos = "center" })
end

local function is_visible()
  return current >= 1 and tabs[current] and tabs[current]:is_open()
end

-- Buffer-local maps for a deck terminal. Normal mode only (press `kj` first),
-- matching the panel's style and keeping the shell's own keys untouched.
local function set_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "gt", function() M.next(vim.v.count) end, opts)
  vim.keymap.set("n", "gT", function() M.prev() end, opts)
  vim.keymap.set("n", "<C-t>", function() M.new_tab() end, opts)
  vim.keymap.set("n", "<leader>x", function() M.close_tab() end, opts)
  -- <C-\> hides the deck too, so the panel key never opens the panel on top of it
  vim.keymap.set({ "n", "t" }, [[<C-\>]], function() M.toggle() end, opts)
end

local function new_term()
  next_id = next_id + 1
  return require("toggleterm.terminal").Terminal:new({
    id = next_id,
    direction = "float",
    -- kept out of toggleterm's own toggle/list heuristics; the deck drives
    -- these terminals directly by object reference.
    hidden = true,
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
    on_exit = function(t)
      if t.__deck_killed then return end -- close_tab already did the bookkeeping
      M._forget(t)
    end,
  })
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

--- Next tab, or jump straight to tab `count` when given (so `{count}gt` works).
function M.next(count)
  if #tabs == 0 then return end
  if count and count > 0 then
    if tabs[count] then show(count) end
    return
  end
  show(current % #tabs + 1)
end

--- Previous tab.
function M.prev()
  if #tabs == 0 then return end
  show((current - 2) % #tabs + 1)
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
