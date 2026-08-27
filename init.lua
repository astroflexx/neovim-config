-- init.lua is the main entrypoint for neovim
-- here, you must only do bootstrapping
-- and calling in other plugins and such

-- anything else, put it in a separate file

vim.loader.enable()

require("core.options")
require("core.keymaps")
require("core.autocmds")

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
