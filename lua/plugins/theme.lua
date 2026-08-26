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

      -- all these colors are set for different tokens in cpp files
      -- to make it match vscode's colors
      -- not audited very well, this is all AI and it works, so I didn't touch it

      vim.api.nvim_set_hl(0, "@keyword", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.type", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.type.cpp", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.modifier", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.modifier.cpp", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.operator", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.operator.cpp", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@operator.reference", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@keyword.new", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.operator.cast", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@function.lambda", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@keyword.delete.bracket", { fg = "#c586c0" })
      vim.api.nvim_set_hl(0, "@keyword.conditional.ternary", { fg = "#d4d4d4" })
      vim.api.nvim_set_hl(0, "@keyword.conditional.ternary.cpp", { fg = "#d4d4d4" })
      vim.api.nvim_set_hl(0, "@function.call", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@function.call.cpp", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@function.method.call", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@function.method.call.cpp", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@type", { fg = "#4ec9b0" })
      vim.api.nvim_set_hl(0, "@type.cpp", { fg = "#4ec9b0" })
      vim.api.nvim_set_hl(0, "@constant.macro", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@constant.macro.cpp", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@constant", { fg = "#9cdcfe" })
      vim.api.nvim_set_hl(0, "@constant.cpp", { fg = "#9cdcfe" })
      vim.api.nvim_set_hl(0, "@constant.builtin", { fg = "#569cd6" })
      vim.api.nvim_set_hl(0, "@constant.builtin.cpp", { fg = "#4fc1ff" })
      vim.api.nvim_set_hl(0, "@string.escape", { fg = "#d7ba7d" })
      vim.api.nvim_set_hl(0, "@string.escape.cpp", { fg = "#d7ba7d" })
      vim.api.nvim_set_hl(0, "@variable.builtin", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@variable.builtin.cpp", { fg = "#dcdcaa" })
      vim.api.nvim_set_hl(0, "@operator.reference.catch", { fg = "#d4d4d4" })
    end,
  },
}
