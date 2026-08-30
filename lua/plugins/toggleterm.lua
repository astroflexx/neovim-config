return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { [[<C-\>]], desc = "Toggle horizontal terminal" },
    { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
  },
  cmd = { "ToggleTerm", "TermExec" },
  config = function()
    require("toggleterm").setup({
      -- vscode-style bottom panel
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      size = 15,
      persist_size = true,
      persist_mode = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
      auto_scroll = true,
      shade_terminals = false,
      -- keep the nvim-tree sidebar full-height (vscode-style): the terminal
      -- spans only the editor width, not the whole screen bottom.
      on_open = function(term)
        -- runs on every toggle (TermOpen only fires once per buffer)
        vim.wo[term.window].scrolloff = 0
        vim.wo[term.window].sidescrolloff = 0

        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "NvimTree" then
            -- nvim_win_call (not set_current_win) so we never leave the terminal
            -- window - otherwise the terminal drops out of insert mode and the
            -- cursor lands on the last blank line on a fresh open.
            local width = vim.api.nvim_win_get_width(win)
            vim.api.nvim_win_call(win, function() vim.cmd("wincmd H") end)
            vim.api.nvim_win_set_width(win, width)
            break
          end
        end
      end,
    })

    -- A neovim terminal buffer is always padded with blank grid rows up to the
    -- window height, and vim happily scrolls down until the *last* line hits the
    -- top of the window - so a fresh shell can be scrolled into a screenful of
    -- emptiness. Only let "scroll down" move while real content is still hidden
    -- below the viewport (line('w$') < line('$')); scrolling up is never blocked.
    local function scroll_down(keys)
      return function()
        if vim.fn.line("w$") < vim.fn.line("$") then
          vim.cmd("normal! " .. vim.api.nvim_replace_termcodes(keys, true, false, true))
        end
      end
    end

    -- make terminal windows behave like an editor pane:
    -- kj to normal mode, <C-h/j/k/l> to move between windows
    local function set_terminal_keymaps()
      vim.wo.scrolloff = 0
      vim.wo.sidescrolloff = 0

      local opts = { buffer = 0 }
      vim.keymap.set("t", "kj", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)

      -- no over-scroll into blank space (<C-d>/<C-f> already clamp themselves)
      vim.keymap.set({ "n", "t" }, "<ScrollWheelDown>", scroll_down("3<C-e>"), opts)
      vim.keymap.set("n", "<C-e>", scroll_down("<C-e>"), opts)
    end

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = set_terminal_keymaps,
    })
  end,
}
