return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  config = function()
    require("bufferline").setup({
      options = {
        modified_icon = "󰅖",
        buffer_close_icon = "󰅖",
        offsets = {
          {
            filetype = "NvimTree",
            text = "",
            separator = true,
          },
        },
      },
    })

    local function sync_modified_hl()
      vim.api.nvim_set_hl(0, "BufferLineModified", { link = "BufferLineCloseButton" })
      vim.api.nvim_set_hl(0, "BufferLineModifiedVisible", { link = "BufferLineCloseButtonVisible" })
      vim.api.nvim_set_hl(0, "BufferLineModifiedSelected", { link = "BufferLineCloseButtonSelected" })
    end

    sync_modified_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.defer_fn(sync_modified_hl, 100)
      end,
    })
  end,
}
