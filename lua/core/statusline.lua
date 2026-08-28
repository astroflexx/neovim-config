local M = {}

local MODE_MAP = {
  ["n"]  = "NORMAL",
  ["no"] = "NORMAL",
  ["v"]  = "VISUAL",
  ["V"]  = "V-LINE",
  ["\22"] = "V-BLOCK",
  ["s"]  = "SELECT",
  ["S"]  = "S-LINE",
  ["\19"] = "S-BLOCK",
  ["i"]  = "INSERT",
  ["R"]  = "REPLACE",
  ["Rv"] = "V-REPLACE",
  ["c"]  = "COMMAND",
  ["t"]  = "TERMINAL",
  ["nt"] = "NORMAL",
}

local function setup_highlights()
  vim.api.nvim_set_hl(0, "StatusLine", { fg = "#d4d4d4", bg = "#2d2d2d" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#808080", bg = "#2d2d2d" })
  vim.api.nvim_set_hl(0, "StMode", { fg = "#1e1e1e", bg = "#569cd6", bold = true })
  vim.api.nvim_set_hl(0, "StLsp", { fg = "#1e1e1e", bg = "#45b550", bold = true })
end

local function get_mode()
  local mode = vim.api.nvim_get_mode().mode
  return MODE_MAP[mode] or mode:upper()
end

local function get_git()
  local signs = vim.b.gitsigns_status_dict
  if not signs then return "" end

  local parts = {}
  if signs.head and signs.head ~= "" then
    parts[#parts + 1] = signs.head
  end
  if (signs.added or 0) > 0 then
    parts[#parts + 1] = "+" .. signs.added
  end
  if (signs.changed or 0) > 0 then
    parts[#parts + 1] = "~" .. signs.changed
  end
  if (signs.removed or 0) > 0 then
    parts[#parts + 1] = "-" .. signs.removed
  end

  if #parts == 0 then return "" end
  return "  " .. table.concat(parts, " ")
end

local function get_lsp()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return "" end
  local names = {}
  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end
  return "%#StLsp#  " .. table.concat(names, ", ") .. "  "
end

function M.render()
  local left = "%#StMode#  " .. get_mode() .. "  %#StatusLine#" .. get_git()
  return left .. "%=" .. get_lsp()
end

setup_highlights()
vim.o.statusline = "%!v:lua.require('core.statusline').render()"

local st_group = vim.api.nvim_create_augroup("StatuslineAu", { clear = true })
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = st_group,
  callback = setup_highlights,
})
vim.api.nvim_create_autocmd("User", {
  group = st_group,
  pattern = "GitSignsUpdate",
  callback = function()
    vim.schedule(function() vim.cmd.redrawstatus() end)
  end,
})
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
  group = st_group,
  callback = function()
    vim.schedule(function() vim.cmd.redrawstatus() end)
  end,
})

return M
