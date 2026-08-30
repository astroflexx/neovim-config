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
      on_open = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "NvimTree" then
            local cur = vim.api.nvim_get_current_win()
            local width = vim.api.nvim_win_get_width(win)
            vim.api.nvim_set_current_win(win)
            vim.cmd("wincmd H")
            vim.api.nvim_win_set_width(win, width)
            vim.api.nvim_set_current_win(cur)
            break
          end
        end
      end,
    })

    -- make terminal windows behave like an editor pane:
    -- <esc> to normal mode, <C-h/j/k/l> to move between windows
    local function set_terminal_keymaps()
      local opts = { buffer = 0 }
      vim.keymap.set("t", "kj", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
    end

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = set_terminal_keymaps,
    })
  end,
}
