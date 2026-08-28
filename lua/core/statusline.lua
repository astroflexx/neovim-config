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
  vim.api.nvim_set_hl(0, "StatusLine", { fg = "#9a9a9a", bg = "#2d2d2d" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#666666", bg = "#2d2d2d" })
  vim.api.nvim_set_hl(0, "StMode", { fg = "#7cb7e8", bg = "#1e3a52", bold = true })
  vim.api.nvim_set_hl(0, "StFormatter", { fg = "#6dc4ab", bg = "#1d3b34", bold = true })
  vim.api.nvim_set_hl(0, "StLinter", { fg = "#d4c477", bg = "#3a3520", bold = true })
  vim.api.nvim_set_hl(0, "StLsp", { fg = "#7dbe84", bg = "#1e3522", bold = true })
end

local function get_mode()
  local mode = vim.api.nvim_get_mode().mode
  return MODE_MAP[mode] or mode:upper()
end

local function stbufnr()
  return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

local function get_formatters()
  local ok, conform = pcall(require, "conform")
  if not ok then return "" end
  local formatters = conform.list_formatters(0)
  if #formatters == 0 then return "" end
  local names = {}
  for _, f in ipairs(formatters) do
    names[#names + 1] = f.name
  end
  return "%#StFormatter#  " .. table.concat(names, ", ") .. "  "
end

local function get_linters()
  local ok, lint = pcall(require, "lint")
  if not ok then return "" end
  local filepath = vim.api.nvim_buf_get_name(stbufnr())
  if filepath:find(vim.fn.expand("$HOME") .. "/test", 1, true) then return "" end
  local linters = lint.linters_by_ft[vim.bo[stbufnr()].filetype] or {}
  if #linters == 0 then return "" end
  return "%#StLinter#  " .. table.concat(linters, ", ") .. "  "
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
  local left = "%#StMode#  " .. get_mode() .. "  %#StatusLine#"
  local right = get_formatters() .. get_linters() .. get_lsp()
  return left .. "%=%#StatusLine#" .. right
end

setup_highlights()
vim.o.statusline = "%!v:lua.require('core.statusline').render()"

local st_group = vim.api.nvim_create_augroup("StatuslineAu", { clear = true })
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = st_group,
  callback = setup_highlights,
})
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
  group = st_group,
  callback = function()
    vim.schedule(function() vim.cmd.redrawstatus() end)
  end,
})

return M
