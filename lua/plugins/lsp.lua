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
  config = function(_, opts)
    opts.ensure_installed = {
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
    }

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Tell every server "I don't support snippets", so completion items come
    -- back as plain text instead of placeholder templates. This is what turns
    -- clangd's `vector<${1:typename Tp}>` (the `vector~` template entry in the
    -- menu) into a plain `vector` that just inserts the identifier, matching
    -- VSCode's default C++ IntelliSense behaviour.
    capabilities.textDocument.completion.completionItem.snippetSupport = false

    -- mason-lspconfig 2.x has no `handlers` / `setup_handlers`: it just calls
    -- `vim.lsp.enable()` for every installed server, pulling per-server config
    -- from `vim.lsp.config()`. So register config there.
    vim.lsp.config("*", { capabilities = capabilities })

    vim.lsp.config("clangd", {
      capabilities = capabilities,
      cmd = {
        "clangd",
        -- Don't insert `(` / argument placeholders when completing a function;
        -- just the name. Belt-and-braces with snippetSupport=false.
        "--function-arg-placeholders=false",
        -- Never auto-add `#include` lines on completion; headers are added by hand.
        "--header-insertion=never",
        "--completion-style=detailed",
      },
    })

    require("mason-lspconfig").setup({ ensure_installed = opts.ensure_installed })
  end,
}
