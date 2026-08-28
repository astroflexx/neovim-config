return {
  "akinsho/bufferline.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  config = function()
    require("bufferline").setup({
      options = {
        indicator = { style = "none" },
        separator_style = { "│", "│" },
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

    local neutral_fg = "#6b6b6b"
    local neutral_bg = "#141516"

    local function fix_bufferline_hls()
      vim.api.nvim_set_hl(0, "BufferLineModified", { link = "BufferLineCloseButton" })
      vim.api.nvim_set_hl(0, "BufferLineModifiedVisible", { link = "BufferLineCloseButtonVisible" })
      vim.api.nvim_set_hl(0, "BufferLineModifiedSelected", { link = "BufferLineCloseButtonSelected" })

      for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
        if name:match("^BufferLine") and not name:match("Selected") and not name:match("DevIcon") then
          local existing = vim.api.nvim_get_hl(0, { name = name })
          vim.api.nvim_set_hl(0, name, { fg = neutral_fg, bg = existing.bg or neutral_bg })
        end
      end

      local sep_fg = "#555555"
      for _, group in ipairs({
        "BufferLineSeparator", "BufferLineSeparatorVisible", "BufferLineSeparatorSelected",
      }) do
        vim.api.nvim_set_hl(0, group, { fg = sep_fg, bg = neutral_bg })
      end
      for _, group in ipairs({
        "BufferLineIndicatorSelected", "BufferLineIndicatorVisible",
      }) do
        vim.api.nvim_set_hl(0, group, { fg = neutral_bg, bg = neutral_bg })
      end

      local sel_bg = vim.api.nvim_get_hl(0, { name = "BufferLineBufferSelected" }).bg
      local sel_fg = vim.api.nvim_get_hl(0, { name = "BufferLineBufferSelected" }).fg
      vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = sel_fg, bg = sel_bg, italic = false, bold = false })
    end

    fix_bufferline_hls()
    vim.api.nvim_create_autocmd({ "ColorScheme", "BufAdd" }, {
      callback = function()
        vim.defer_fn(fix_bufferline_hls, 100)
      end,
    })
  end,
}
