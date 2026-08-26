-- theme.lua is a plugin to further customize the vscode theme
-- to make it more like vscode

return {
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("vscode").setup({
        style = "dark",
        transparent = false,
        color_overrides = {
          vscBack = "#141516",
          vscLeftDark = "#0f1011",
          vscPopupBack = "#0f1011",
        },
      })
      require("vscode").load()

      -- treesitter and lsp token colors to match vscode

      vim.api.nvim_set_hl(0, "@keyword", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.type", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.modifier", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.operator", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@operator.reference", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.new", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.operator.cast", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@function.lambda", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@keyword.delete.bracket", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.conditional.ternary", { fg = "#d4d4d4" })
      vim.api.nvim_set_hl(0, "@function.call", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@function.method.call", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@type", { fg = "#4ec9b0" })
      vim.api.nvim_set_hl(0, "@constant.macro", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@constant", { fg = "#9cdcfe" })
      vim.api.nvim_set_hl(0, "@constant.builtin", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@string.escape", { fg = "#d7ba7d" })
      vim.api.nvim_set_hl(0, "@variable.builtin", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@variable.builtin.cpp", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@operator.reference.catch", { fg = "#d4d4d4" })

      -- lsp semantic token colors matching vscode
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
      vim.api.nvim_set_hl(0, "@lsp.typemod.class.deduced", { fg = "#569cd6" })
    end,
  },
}
