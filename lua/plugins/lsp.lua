-- lsp.lua is the lsp plugin for intellisense, diagnostics, etc.

return {
  "mason-org/mason-lspconfig.nvim",
  lazy = false,
  dependencies = {
    { "mason-org/mason.nvim", opts = {} },
    "neovim/nvim-lspconfig",
  },
  opts = {
    ensure_installed = {
      "clangd",
      "rust_analyzer",
      "gopls",
      "jdtls",
      "pyright",
      "lua_ls",
      "jsonls",
      "html",
      "cssls",
      "bashls",
    },
  },
}
