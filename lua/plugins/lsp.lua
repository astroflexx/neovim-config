-- lsp.lua is the lsp plugin for intellisense, diagnostics, etc.

return {
  "mason-org/mason-lspconfig.nvim",
  event = "VeryLazy",
  dependencies = {
    {
      "mason-org/mason.nvim",
      config = function()
        local nvm_node = vim.fn.glob("$HOME/.nvm/versions/node/v*", false, true)
        if #nvm_node > 0 then
          vim.env.PATH = nvm_node[#nvm_node] .. "/bin:" .. vim.env.PATH
        end
        require("mason").setup()
      end,
    },
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
