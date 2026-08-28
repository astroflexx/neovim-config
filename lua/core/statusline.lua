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

local red = "#e06c75"
local green = "#45b550"
local stl_bg = "#1e1f20"

local sep_l = "\u{e0b6}"
local icon_fmt = "\u{f0c9}"
local icon_lsp = "\u{f013}"

local function setup_highlights()
  vim.api.nvim_set_hl(0, "StatusLine", { fg = "#9a9a9a", bg = stl_bg })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#666666", bg = stl_bg })
  vim.api.nvim_set_hl(0, "StMode", { fg = "#000000", bg = "#569cd6", bold = true })

  vim.api.nvim_set_hl(0, "StFmtSep", { fg = red, bg = stl_bg })
  vim.api.nvim_set_hl(0, "StFmtBody", { fg = "#000000", bg = red, bold = true })

  vim.api.nvim_set_hl(0, "StLspSep", { fg = green, bg = stl_bg })
  vim.api.nvim_set_hl(0, "StLspBody", { fg = "#000000", bg = green, bold = true })

  vim.api.nvim_set_hl(0, "StFmtToLsp", { fg = green, bg = red })
end

local function get_mode()
  local mode = vim.api.nvim_get_mode().mode
  return MODE_MAP[mode] or mode:upper()
end

local function find_editor_buf()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "NvimTree" then
      return buf
    end
  end
  return vim.api.nvim_get_current_buf()
end

local function get_formatter_info(buf)
  local ok, conform = pcall(require, "conform")
  if not ok then return nil end
  local formatters = conform.list_formatters(buf)
  if #formatters == 0 then return nil end
  local names = {}
  for _, f in ipairs(formatters) do
    names[#names + 1] = f.name
  end
  return table.concat(names, ", ")
end

local function get_lsp_info(buf)
  local clients = vim.lsp.get_clients({ bufnr = buf })
  if #clients == 0 then return nil end
  local names = {}
  for _, client in ipairs(clients) do
    names[#names + 1] = client.name
  end
  return table.concat(names, ", ")
end

function M.render()
  local buf = find_editor_buf()

  local left = "%#StMode#  " .. get_mode() .. "  %#StatusLine#"

  local sections = {}
  local fmt = get_formatter_info(buf)
  if fmt then sections[#sections + 1] = { body = "StFmtBody", sep = "StFmtSep", icon = icon_fmt, text = fmt, color = "Fmt" } end
  local lsp = get_lsp_info(buf)
  if lsp then sections[#sections + 1] = { body = "StLspBody", sep = "StLspSep", icon = icon_lsp, text = lsp, color = "Lsp" } end

  local right = ""
  local transition_map = {
    FmtLsp = "StFmtToLsp",
  }

  for _, sec in ipairs(sections) do
    right = right .. "%#" .. sec.body .. "#  " .. sec.icon .. " " .. sec.text .. "  "
  end

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
