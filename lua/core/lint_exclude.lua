local M = {}

local excluded_dirs = { "/test", "/problem-solving" }

function M.is_excluded(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr or 0)
  local home = vim.fn.expand("$HOME")
  for _, dir in ipairs(excluded_dirs) do
    if filepath:find(home .. dir, 1, true) then
      return true
    end
  end
  return false
end

return M
