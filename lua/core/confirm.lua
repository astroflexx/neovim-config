-- Shared small centred yes/no modal, used anywhere an action needs a
-- confirmation before something is lost (killing a busy terminal, closing an
-- unsaved buffer, ...). Blocks until the user answers: `y` confirms, `n` /
-- `q` / <Esc> cancel, any other key is ignored. Returns true only on an
-- explicit yes.

local M = {}

-- Title text picks up the shell prompt's green: nvim exposes the 16 ANSI
-- colours the terminal renders with as g:terminal_color_0..15. Re-applied on
-- ColorScheme since a theme swap redefines them.
local function set_hl()
  vim.api.nvim_set_hl(0, "ConfirmModalTitle", {
    fg = vim.g.terminal_color_2 or vim.g.terminal_color_10 or "#6A9955",
    bold = true,
  })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = vim.schedule_wrap(set_hl) })

--- Show a centred confirm modal. `title` is the float's border title, `body`
--- is the question line (e.g. "foo.txt has unsaved changes.").
function M.ask(title, body)
  local lines = {
    "",
    "  " .. body,
    "",
    "  Continue anyway?    [y] yes    [n] no",
    "",
  }
  local width = 4
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l) + 2) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    focusable = false,
    noautocmd = true,
    zindex = 250,
  })
  vim.wo[win].winhighlight = "NormalFloat:Normal,FloatBorder:WinSeparator,FloatTitle:ConfirmModalTitle"
  vim.cmd("redraw")

  local answer
  while answer == nil do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then
      answer = false
    else
      ch = ch:lower()
      if ch == "y" then
        answer = true
      elseif ch == "n" or ch == "q" or ch == "\27" then
        answer = false
      end
    end
  end

  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  return answer
end

return M
