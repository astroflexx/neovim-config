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
        -- reserve the left column so the buffer tabs stay put instead of
        -- sliding right when nvim-tree or the dap-ui panel opens. one entry
        -- per filetype that can sit at the top of the left column.
        offsets = {
          {
            filetype = "NvimTree",
            text = "",
            separator = true,
          },
          {
            filetype = "dapui_controls",
            text = "DEBUG",
            separator = false,
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
      -- the "repository/" prefix bufferline adds to same-named files; match the
      -- filename instead of the theme's green italic
      vim.api.nvim_set_hl(0, "BufferLineDuplicateSelected", { fg = sel_fg, bg = sel_bg, italic = false, bold = false })
    end

    fix_bufferline_hls()

    local map = vim.keymap.set

    -- current buffer's index in the *visible* tab order (which can differ
    -- from buffer-number order after a tab is moved), plus the tab count.
    -- used to stop h/l from wrapping past the ends.
    local function tab_pos()
      local ok, state = pcall(require, "bufferline.state")
      if not ok or not state.components then
        return nil, nil
      end
      local cur = vim.api.nvim_get_current_buf()
      for i, c in ipairs(state.components) do
        if c.id == cur then
          return i, #state.components
        end
      end
      return nil, #state.components
    end

    map("n", "<leader>h", function()
      local i = tab_pos()
      if not i or i > 1 then
        vim.cmd("BufferLineCyclePrev")
      end
    end, { desc = "Previous buffer" })

    map("n", "<leader>l", function()
      local i, n = tab_pos()
      if not i or i < n then
        vim.cmd("BufferLineCycleNext")
      end
    end, { desc = "Next buffer" })
    for i = 1, 9 do
      map("n", "<leader>" .. i, function()
        require("bufferline").go_to(i, true)
      end, { desc = "Go to buffer " .. i })
    end

    vim.api.nvim_create_autocmd({ "ColorScheme", "BufAdd" }, {
      callback = function()
        vim.defer_fn(fix_bufferline_hls, 100)
      end,
    })
  end,
}
