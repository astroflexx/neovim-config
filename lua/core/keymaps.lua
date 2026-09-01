-- keymaps.lua is to set global keymappings

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- use "kj" to switch from any mode to normal mode
map("i", "kj", "<Esc>")
map("v", "kj", "<Esc>")
map("c", "kj", "<Esc>")

map("n", "<leader>q", "<cmd>qa<cr>")

-- lsp navigation
map("n", "<leader>gd", "<C-]>")
map("n", "<leader>gs", "<C-w>]")
map("n", "<leader>gp", "<C-w>}")
-- <leader>d is the debug prefix (see lua/plugins/dap.lua); diagnostics float lives on <leader>c
map("n", "<leader>c", vim.diagnostic.open_float)
map("n", "<leader>s", vim.lsp.buf.signature_help)
map("n", "<leader>x", function()
  local bt = vim.bo.buftype
  local ft = vim.bo.filetype
  if ft == "NvimTree" then
    require("nvim-tree.api").tree.close()
    local bufs = vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
    if #bufs == 0 or (#bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" and not vim.bo[bufs[1]].modified) then
      vim.cmd("qa")
    end
  elseif bt == "" then
    local tree_open = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
        tree_open = true
        break
      end
    end
    local buf_to_delete = vim.api.nvim_get_current_buf()
    vim.cmd("bprevious")
    if vim.api.nvim_get_current_buf() == buf_to_delete then
      vim.cmd("enew")
    end
    vim.cmd("bdelete " .. buf_to_delete)
    local bufs = vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
    local only_empty = #bufs == 0 or (#bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" and not vim.bo[bufs[1]].modified)
    if only_empty and tree_open then
      vim.cmd("NvimTreeFocus")
      if #bufs == 1 then vim.cmd("bdelete " .. bufs[1]) end
    elseif only_empty then
      vim.cmd("qa")
    end
  else
    vim.cmd("q")
  end
end)
