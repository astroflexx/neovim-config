-- options.lua is a settings file, to set some global options

local opt = vim.opt

-- direct port from my .vimrc
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.number = true

-- neovim essentials
opt.smartindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.splitbelow = true
opt.splitright = true
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.updatetime = 250
opt.mouse = "a"
opt.timeoutlen = 400
opt.showmode = false
opt.laststatus = 3

-- cursor and its color
opt.guicursor = "n-v-o:block-Cursor-blinkon1-blinkoff1-blinkwait1,i-ci-ve:ver25-Cursor-blinkon1-blinkoff1-blinkwait1,r-cr:hor20-Cursor-blinkon1-blinkoff1-blinkwait1"
vim.api.nvim_set_hl(0, "Cursor", { fg = "#000000", bg = "#a0a0a0" })
