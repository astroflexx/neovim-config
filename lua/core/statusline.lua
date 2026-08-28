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
  vim.api.nvim_set_hl(0, "StGit", { fg = "#1e1e1e", bg = "#8668c4", bold = true })
  vim.api.nvim_set_hl(0, "StFormatter", { fg = "#1e1e1e", bg = "#4ec9b0", bold = true })
  vim.api.nvim_set_hl(0, "StLinter", { fg = "#1e1e1e", bg = "#dcdcaa", bold = true })
  vim.api.nvim_set_hl(0, "StLsp", { fg = "#1e1e1e", bg = "#45b550", bold = true })
end

local function get_mode()
  local mode = vim.api.nvim_get_mode().mode
  return MODE_MAP[mode] or mode:upper()
end

local function stbufnr()
  return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

local function get_git()
  local bufnr = stbufnr()
  if not vim.b[bufnr].gitsigns_head then return "" end

  local git_status = vim.b[bufnr].gitsigns_status_dict

  local added = (git_status.added and git_status.added ~= 0) and ("  \u{f067} " .. git_status.added) or ""
  local changed = (git_status.changed and git_status.changed ~= 0) and ("  \u{f459} " .. git_status.changed) or ""
  local removed = (git_status.removed and git_status.removed ~= 0) and ("  \u{f068} " .. git_status.removed) or ""
  local branch_name = "\u{f418} " .. git_status.head

  return "%#StGit#  " .. branch_name .. added .. changed .. removed .. "  %#StatusLine#"
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
  local left = "%#StMode#  " .. get_mode() .. "  %#StatusLine#" .. get_git()
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
