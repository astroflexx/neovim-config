-- comment.lua: Ctrl+/ line-comment toggling, like VSCode.
--
-- Comment.nvim picks the comment string ("//", "#", "--", "<!-- -->", ...)
-- per filetype, and nvim-ts-context-commentstring refines that per treesitter
-- node so embedded languages (e.g. <script> inside html, css-in-js) use the
-- right comment style at the cursor - the same thing VSCode's tokenizer does.
--
-- Terminals don't have a distinct "Ctrl+/" keycode: most send <C-_> (0x1F),
-- some newer ones (kitty, wezterm, or nvim's own :terminal) send <C-/>
-- literally. Both are mapped to the same toggle so it works everywhere.

return {
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
    config = function()
      -- use the manual integration below instead of the plugin's own
      -- (deprecated) auto-hooking module
      vim.g.skip_ts_context_commentstring_module = true

      require("Comment").setup({
        pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      })

      local api = require("Comment.api")

      local function toggle_current_line_insert()
        local win = vim.api.nvim_get_current_win()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local row, col = cursor[1], cursor[2]
        local before = vim.api.nvim_get_current_line()

        vim.cmd("stopinsert")
        api.toggle.linewise.current()

        local after = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
        -- keep the cursor over the same code, sliding it past/with whatever
        -- comment markers were just added or removed before it
        local new_col = col + (#after - #before)
        if new_col < 0 then new_col = 0 end
        vim.api.nvim_win_set_cursor(win, { row, new_col })
        vim.cmd("startinsert")
      end

      local function toggle_visual()
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
          "nx",
          false
        )
        api.toggle.linewise(vim.fn.visualmode())
      end

      for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
        vim.keymap.set("n", lhs, api.toggle.linewise.current, { desc = "toggle line comment" })
        vim.keymap.set("x", lhs, toggle_visual, { desc = "toggle line comment" })
        vim.keymap.set("i", lhs, toggle_current_line_insert, { desc = "toggle line comment" })
      end
    end,
  },
}
