-- keymaps.lua is to set global keymappings

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- use "kj" to switch from any mode to normal mode
map("i", "kj", "<Esc>")
map("v", "kj", "<Esc>")
map("c", "kj", "<Esc>")

map("n", "<leader>q", "<cmd>qa<cr>")
