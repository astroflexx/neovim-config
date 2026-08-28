return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  opts = {
    options = {
      offsets = {
        {
          filetype = "NvimTree",
          text = "",
          separator = true,
        },
      },
    },
  },
}
