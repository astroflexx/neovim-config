-- rainbow.lua is a plugin to color the bracket pairs
-- we want to follow vscode's way of coloring bracket pairs, based on their nesting

return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "BufReadPost",
  config = function()
    local rainbow = require("rainbow-delimiters")

    -- match vscode's bracket pair colors: yellow -> purple -> cyan
    vim.api.nvim_set_hl(0, "RainbowDelimiter1", { fg = "#ffd700" })
    vim.api.nvim_set_hl(0, "RainbowDelimiter2", { fg = "#da70d6" })
    vim.api.nvim_set_hl(0, "RainbowDelimiter3", { fg = "#179fff" })

    local default = require("rainbow-delimiters.default")

    require("rainbow-delimiters.setup").setup({
      strategy = default.strategy,
      query = default.query,
      highlight = {
        "RainbowDelimiter1",
        "RainbowDelimiter2",
        "RainbowDelimiter3",
      },
    })
  end,
}
