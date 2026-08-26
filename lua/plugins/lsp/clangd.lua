-- clangd.lua is the clangd lsp plugin for c/c++

return {
  "neovim/nvim-lspconfig",
  event = "BufReadPost",
  config = function()
    vim.lsp.enable("clangd")

    -- colors matching vscode theme

    vim.api.nvim_set_hl(0, "@lsp.type.variable", { fg = "#9cdcfe" })
    vim.api.nvim_set_hl(0, "@lsp.type.parameter", { fg = "#9cdcfe" })
    vim.api.nvim_set_hl(0, "@lsp.type.property", { fg = "#9cdcfe" })
    vim.api.nvim_set_hl(0, "@lsp.type.function", { fg = "#dcdcaa" })
    vim.api.nvim_set_hl(0, "@lsp.type.method", { fg = "#dcdcaa" })
    vim.api.nvim_set_hl(0, "@lsp.type.type", { fg = "#4ec9b0" })
    vim.api.nvim_set_hl(0, "@lsp.type.class", { fg = "#4ec9b0" })
    vim.api.nvim_set_hl(0, "@lsp.type.enum", { fg = "#4ec9b0" })
    vim.api.nvim_set_hl(0, "@lsp.type.enumMember", { fg = "#4fc1ff" })
    vim.api.nvim_set_hl(0, "@lsp.type.namespace", { fg = "#4ec9b0" })
    vim.api.nvim_set_hl(0, "@lsp.type.macro", { fg = "#569cd6" })
    vim.api.nvim_set_hl(0, "@lsp.type.keyword", { fg = "#c586c0" })
    vim.api.nvim_set_hl(0, "@lsp.type.typeParameter", { fg = "#4ec9b0" })
    vim.api.nvim_set_hl(0, "@lsp.mod.readonly", {})
    vim.api.nvim_set_hl(0, "@lsp.type.operator", {})
    vim.api.nvim_set_hl(0, "@lsp.typemod.class.constructorOrDestructor", { fg = "#dcdcaa" })
    vim.api.nvim_set_hl(0, "@lsp.typemod.class.constructorOrDestructor.cpp", { fg = "#dcdcaa" })
    vim.api.nvim_set_hl(0, "@lsp.typemod.class.deduced", { fg = "#569cd6" })
    vim.api.nvim_set_hl(0, "@lsp.typemod.class.deduced.cpp", { fg = "#569cd6" })
  end,
}
