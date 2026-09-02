-- core/snippets.lua -- competitive-programming snippet picker.
--
-- The snippets are the .cpp files under ~/algo, each carrying inline VS Code
-- tabstop markers ($1, $2, $0). A build script (~/algo/generate_snippets.py)
-- flattens them into ~/.config/nvim/snippets/cpp.json:
--
--   prefix      = file stem            (unique across the repo)
--   body        = the file, verbatim   (with its $1 / $2 / $0 tabstops)
--   description = its first `//` line
--
-- They are deliberately kept OUT of the completion menu. In VS Code a stray
-- <CR> on a half-typed `seg` would dump the whole segment tree; here nothing
-- reaches cmp. Instead <leader>a (mapped per-buffer in after/ftplugin/cpp.lua)
-- opens a modal buffer:
--
--   * type on the top line to fuzzy-filter the list below
--   * <CR> inserts the selected snippet -- the first row, unless you have moved
--     the cursor onto another one
--   * `kj` leaves insert mode (as everywhere), then j/k move the selection
--   * <leader>x dismisses it, like any other buffer
--
-- Expansion runs through vim.snippet (already the engine wired in cmp.lua), so
-- <Tab> / <S-Tab> jump between the $1.. $0 stops -- that mapping lives in
-- cmp.lua so it can share the key with the completion menu.

local M = {}

local json_path = vim.fn.stdpath("config") .. "/snippets/cpp.json"

-- vim.snippet.expand() parses the body as an LSP snippet, so a literal `$` in
-- the C++ (e.g. manacher's sentinel `t = "$" + t + "^"`) is read as a malformed
-- tabstop and the whole parse fails. The snippet files only ever use `$1`..`$9`,
-- `$0` and `${1:...}` as genuine tabstops -- backslash-escape every other `$`.
local function escape_stray_dollars(body)
  return (body:gsub("%$()", function(pos)
    local nxt = body:sub(pos, pos)
    if nxt:match("%d") or (nxt == "{" and body:sub(pos + 1, pos + 1):match("%d")) then
      return "$"
    end
    return "\\$"
  end))
end

-- The group the float's border actually resolves to (see the `winhighlight`
-- below). Named once because the title padding has to match it exactly.
local BORDER_HL = "WinSeparator"

-- How many columns left of dead centre the title word sits.
local TITLE_SHIFT = 2

-- Re-applied on ColorScheme: loading a theme runs `hi clear`.
local function set_hls()
  vim.api.nvim_set_hl(0, "AlgoSnippetSel", { link = "PmenuSel", default = true })
  -- the hint text and the divider rule: plain white, not the theme's green
  -- Comment / near-invisible WinSeparator.
  vim.api.nvim_set_hl(0, "AlgoSnippetDim", { fg = "#d4d4d4" })
end
set_hls()
vim.api.nvim_create_autocmd("ColorScheme", { callback = vim.schedule_wrap(set_hls) })

-- Load + normalise the generated JSON on every open: the file is tiny, and
-- re-reading it means the list is fresh the moment you re-run the build script
-- -- no reload command to remember.
local function load_items()
  local fh = io.open(json_path, "r")
  if not fh then
    return nil, "no snippet file at " .. json_path .. " -- run generate_snippets.py"
  end
  local raw = fh:read("*a")
  fh:close()

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return nil, "could not parse " .. json_path
  end

  local items = {}
  for _, snip in pairs(data) do
    local body = snip.body
    if type(body) == "table" then
      body = table.concat(body, "\n")
    end
    items[#items + 1] = {
      prefix = snip.prefix or "?",
      desc = snip.description or "",
      body = escape_stray_dollars(body or ""),
    }
  end
  table.sort(items, function(a, b) return a.prefix < b.prefix end)
  return items
end

function M.open()
  local items, err = load_items()
  if not items then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  if #items == 0 then
    vim.notify("no snippets defined", vim.log.levels.WARN)
    return
  end

  local origin_win = vim.api.nvim_get_current_win()
  local origin_cur = vim.api.nvim_win_get_cursor(origin_win)

  local prefixes = vim.tbl_map(function(it) return it.prefix end, items)
  local by_prefix = {}
  for _, it in ipairs(items) do
    by_prefix[it.prefix] = it
  end

  local width = math.min(72, math.max(40, math.floor(vim.o.columns * 0.6)))
  local rule = string.rep("─", width)
  local height = math.min(#items + 2, math.max(8, math.floor(vim.o.lines * 0.6)))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  -- keep cmp entirely off this buffer -- both its auto menu and the manual
  -- `cmp.complete()` its refresh-on-delete autocmd fires. cmp.lua's `enabled`
  -- and that autocmd both bail when this var is set (buffer-level
  -- `enabled = false` does not stop a Manual `cmp.complete()`).
  vim.b[buf].algo_snippet_modal = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    -- The title is painted INTO the top border, replacing that slice of the
    -- rule -- so padding it with spaces to nudge the word off dead centre (a
    -- cursor sits there; the word reads better just left of it) leaves a hole
    -- in the border. `title` takes [text, highlight] chunks, so the padding is
    -- the border glyph itself wearing the border's highlight: the rule stays
    -- unbroken, and centring title+pad puts the word TITLE_SHIFT columns left.
    title = {
      { " snippets ", "FloatTitle" },
      { string.rep("─", TITLE_SHIFT * 2), BORDER_HL },
    },
    title_pos = "center",
    zindex = 100,
  })
  vim.wo[win].winhighlight = "NormalFloat:Normal,FloatBorder:" .. BORDER_HL
  vim.wo[win].wrap = false
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0

  local sel_ns = vim.api.nvim_create_namespace("algo_snippets_sel")
  local hint_ns = vim.api.nvim_create_namespace("algo_snippets_hint")
  local sep_ns = vim.api.nvim_create_namespace("algo_snippets_sep")

  local filtered = items -- the items currently listed on lines 2..
  local last_query = nil
  local closing = false

  -- Buffer layout: line 1 = query, line 2 = blank spacer, lines 3.. = the list.
  local LIST_TOP = 3

  -- The effective selection: the row the cursor is on, or the first row while
  -- the cursor is still up in the query / spacer rows. 1-based into `filtered`.
  local function sel_index()
    if #filtered == 0 then
      return nil
    end
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local idx = row >= LIST_TOP and (row - LIST_TOP + 1) or 1
    return math.min(idx, #filtered)
  end

  local function paint_selection()
    vim.api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
    local idx = sel_index()
    if idx then
      vim.api.nvim_buf_set_extmark(buf, sel_ns, idx + LIST_TOP - 2, 0, { line_hl_group = "AlgoSnippetSel" })
    end
  end

  local function render()
    local q = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
    if q == last_query then
      return
    end
    last_query = q

    if q == "" then
      filtered = items
    else
      filtered = vim.tbl_map(function(n) return by_prefix[n] end, vim.fn.matchfuzzy(prefixes, q))
    end

    local lines = {}
    for _, it in ipairs(filtered) do
      if it.desc ~= "" then
        lines[#lines + 1] = string.format("%-28s  %s", it.prefix, it.desc)
      else
        lines[#lines + 1] = it.prefix
      end
    end
    if #lines == 0 then
      lines = { "  (no match)" }
    end
    table.insert(lines, 1, rule) -- divider row between the query line and list
    vim.api.nvim_buf_set_lines(buf, 1, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf, sep_ns, 0, -1)
    vim.api.nvim_buf_set_extmark(buf, sep_ns, 1, 0, {
      end_col = #rule,
      hl_group = "AlgoSnippetDim",
    })

    vim.api.nvim_buf_clear_namespace(buf, hint_ns, 0, -1)
    if q == "" then
      -- "overlay" at column 0 puts the hint exactly where a list row's text
      -- sits -- flush under the border, no stray leading gap that "eol" adds.
      vim.api.nvim_buf_set_extmark(buf, hint_ns, 0, 0, {
        virt_text = { { "type to filter", "AlgoSnippetDim" } },
        virt_text_pos = "overlay",
      })
    end

    paint_selection()
  end

  local function dismiss()
    if closing then
      return
    end
    closing = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function accept()
    local idx = sel_index()
    local item = idx and filtered[idx]
    if not item then
      return
    end
    dismiss()
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(origin_win) then
        return
      end
      vim.api.nvim_set_current_win(origin_win)
      pcall(vim.api.nvim_win_set_cursor, origin_win, origin_cur)
      vim.snippet.expand(item.body)
    end)
  end

  render()

  local kopts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set({ "i", "n" }, "<CR>", accept, kopts)
  vim.keymap.set("n", "<leader>x", dismiss, kopts)

  -- The query lives on real buffer line 1, with the divider rule on line 2. The
  -- line-kill operators would delete line 1 outright, pulling the rule up so it
  -- reads as the query ("(no match)"). Rebind them to just blank the query.
  local function clear_query(insert)
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "" })
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    last_query = nil
    render()
    if insert then
      vim.cmd.startinsert()
    end
  end
  for _, lhs in ipairs({ "dd", "D" }) do
    vim.keymap.set("n", lhs, function() clear_query(false) end, kopts)
  end
  for _, lhs in ipairs({ "cc", "C", "S" }) do
    vim.keymap.set("n", lhs, function() clear_query(true) end, kopts)
  end

  local grp = vim.api.nvim_create_augroup("algo_snippets_" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = grp,
    buffer = buf,
    callback = function()
      -- an edit on a list row (e.g. a stray `i` after `kj`) must not stick:
      -- drop the cache so the list is rebuilt from the query verbatim.
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_cursor(win)[1] ~= 1 then
        last_query = nil
      end
      render()
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = grp,
    buffer = buf,
    callback = paint_selection,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = grp,
    buffer = buf,
    once = true,
    callback = dismiss,
  })

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd.startinsert()
end

return M
