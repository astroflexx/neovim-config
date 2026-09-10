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

    -- Snippet support has to stay on: clangd only offers its keyword-pattern
    -- completions for control-flow statements (`for`, `while`, `do`, ...) when
    -- the client claims snippet support -- a bare "for" with no placeholders
    -- for the loop header wouldn't be useful, so clangd skips the item
    -- entirely otherwise. This also lets template-y entries like
    -- `vector<${1:typename Tp}>~` back in; cmp.lua's lsp_entry_filter strips
    -- those placeholders back down to a plain `vector` insert.
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -- mason-lspconfig 2.x has no `handlers` / `setup_handlers`: it just calls
    -- `vim.lsp.enable()` for every installed server, pulling per-server config
    -- from `vim.lsp.config()`. So register config there.
    vim.lsp.config("*", { capabilities = capabilities })

    vim.lsp.config("clangd", {
      capabilities = capabilities,
      cmd = {
        "clangd",
        -- Don't insert argument placeholders when completing a function call
        -- (still inserts the `()`, just no `${1:arg}` snippet stops inside).
        "--function-arg-placeholders=false",
        -- Never auto-add `#include` lines on completion; headers are added by hand.
        "--header-insertion=never",
        -- Combine overloads (e.g. every vector constructor) into ONE menu entry.
        -- `detailed` is what exploded `vec` into 10 identical "vector" rows.
        "--completion-style=bundled",
      },
    })

    require("mason-lspconfig").setup({ ensure_installed = opts.ensure_installed })
  end,
}
