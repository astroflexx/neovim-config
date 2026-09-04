-- The <leader>t bottom terminal - VSCode's panel.
--
-- It is a real horizontal split (not a float) living *under the editor window*:
-- the editor genuinely shrinks to the space above it, so `j`/`k`/scroll behave
-- normally while the terminal is open. A float can't do this - it's drawn on top
-- of a full-height editor window, so the cursor just walks off screen behind it.
--
--   <leader>t / <C-\>   closed            -> open + focus
--                       open, not focused -> focus it
--                       open, focused     -> does nothing
--   <leader>x           kill the shell (only while focused in it)
--
-- toggleterm creates the split with `botright split` (full width, steals rows
-- from the tree too); on_open then re-parents it under the editor with
-- `win_splitmove` so the file tree keeps its full height.

local M = {}

M.ID = 1
local HEIGHT_RATIO = 0.45

function M.height()
  return math.max(6, math.floor(vim.o.lines * HEIGHT_RATIO))
end

local function editor_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "NvimTree" then
      return w
    end
  end
end

--- Called from toggleterm's on_open for id 1: move the fresh bottom split so it
--- splits only the editor window, size it, and pin the height.
function M.on_open(term)
  if term.id ~= M.ID or not (term.window and vim.api.nvim_win_is_valid(term.window)) then
    return
  end
  local editor = editor_win()
  if editor and editor ~= term.window then
    pcall(vim.fn.win_splitmove, term.window, editor, { vertical = false, rightbelow = true })
  end
  pcall(vim.api.nvim_win_set_height, term.window, M.height())
  vim.wo[term.window].winfixheight = true
  vim.wo[term.window].scrolloff = 0
  vim.wo[term.window].sidescrolloff = 0
  vim.api.nvim_set_current_win(term.window)
  vim.schedule(function() vim.cmd("startinsert") end)
end

function M.toggle()
  local tt = require("toggleterm.terminal")
  local term = tt.get(M.ID)
  if term and term:is_open() then
    if not term:is_focused() then
      term:focus()
      vim.schedule(function() vim.cmd("startinsert") end)
    end
    return
  end
  ;(term or tt.Terminal:new({ id = M.ID })):open()
end

return M
