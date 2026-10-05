-- VSCode-style block comments for C/C++ (wired up in plugins/autopairs.lua).
--
-- Typing "/*" auto-closes to "/* */". Enter between the pair then gives:
--
--   /*            /**
--       |          * |
--   */             */
--
-- i.e. a plain comment is free text one indent level in (matching what `o`
-- gives, via cinoptions in after/ftplugin/cpp.lua), and only a
-- "/**" doc comment gets the " * " leader (which 'comments' in
-- after/ftplugin/cpp.lua keeps continuing on further Enters).

local M = {}

-- Split the current line at the cursor around the " */" that follows it.
function M.expand(doc)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  local after = line:sub(col + 1):gsub("^%s*%*/", "", 1)
  local indent = line:match("^%s*")

  local mid, close
  if doc then
    mid, close = indent .. " * ", indent .. " */"
  else
    mid, close = indent .. string.rep(" ", vim.fn.shiftwidth()), indent .. "*/"
  end

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { before, mid, close .. after })
  vim.api.nvim_win_set_cursor(0, { row + 1, #mid })
end

return M
