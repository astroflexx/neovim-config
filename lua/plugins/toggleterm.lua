-- vscode's bottom panel, reproduced as an *overlay*.
--
-- a split terminal has to steal its rows from somebody: opening one shrinks the
-- editor and shifts every line of the file up. a floating window is the only
-- layout that doesn't - it is drawn on top of the tree and the editor, which
-- keep the exact geometry they had before the toggle - so this terminal is a
-- float pinned to the bottom of the screen rather than a horizontal split.
--
-- the geometry below is measured off vscode's panel at the same window size.

-- share of the screen the panel covers (vscode: a little over half). a ratio
-- rather than a fixed row count, so the panel keeps its proportions if the font
-- size or the window changes.
local PANEL_RATIO = 0.54

-- columns owned by the file tree, including the separator column to its right;
-- the panel starts after them so the tree stays fully visible, like vscode's
-- explorer. 0 when the tree is closed - the panel then spans the full width.
local function tree_columns()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return vim.api.nvim_win_get_width(win) + 1
    end
  end
  return 0
end

local function panel_height()
  return math.floor(vim.o.lines * PANEL_RATIO + 0.5)
end

-- first screen row the window area no longer owns: the command line, plus the
-- global statusline (laststatus = 3, see core/options.lua). the panel's bottom
-- edge sits here, so the statusline stays visible underneath it.
local function panel_bottom()
  return vim.o.lines - vim.o.cmdheight - (vim.o.laststatus == 3 and 1 or 0)
end

-- the panel's outer top row, and the rows left for the terminal below it
local function panel_row() return panel_bottom() - panel_height() end
local function panel_rows() return panel_height() - 1 end

-- the panel's edges, drawn in WinSeparator so the seam looks exactly like the
-- horizontal split's did. `row`/`col` are the *outer* edge - the border sits on
-- them and the content starts one cell in - so the height gives that row back,
-- keeping the panel the same size it is without a border.
--
-- the left edge is the interesting one: it lands on the tree's own separator
-- column, continuing that line down and meeting the top edge in a proper join
-- rather than leaving a notch between the two. with no tree there is no line to
-- meet, and nvim clamps the overhanging column onto column 0 instead of letting
-- it fall off screen, so that case uses a plain top edge (see on_open).
local BORDER_JOINED = { "\u{251c}", "\u{2500}", "", "", "", "", "", "\u{2502}" }
local BORDER_TOP_ONLY = { "", "\u{2500}", "", "", "", "", "", "" }

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { [[<C-\>]], desc = "Toggle terminal panel" },
    { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal panel" },
  },
  cmd = { "ToggleTerm", "TermExec" },
  config = function()
    require("toggleterm").setup({
      open_mapping = [[<C-\>]],
      direction = "float",
      -- width/height/row/col accept a function, re-evaluated on every open and
      -- on VimResized, which is what lets the panel track the tree's width.
      float_opts = {
        border = BORDER_JOINED,
        height = panel_rows,
        width = function() return vim.o.columns - tree_columns() end,
        row = panel_row,
        col = function() return tree_columns() - 1 end,
      },
      -- same colour the split separator had, so the seam looks unchanged
      highlights = { FloatBorder = { link = "WinSeparator" } },
      persist_mode = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
      auto_scroll = true,
      shade_terminals = false,
      on_open = function(term)
        -- every toggle builds a brand new floating window, so window-local
        -- options have to be re-applied here rather than once at TermOpen.
        vim.wo[term.window].scrolloff = 0
        vim.wo[term.window].sidescrolloff = 0

        -- no tree, no separator to join: drop the left edge and take back the
        -- column nvim clamped it into.
        if tree_columns() == 0 then
          vim.api.nvim_win_set_config(term.window, {
            relative = "editor",
            border = BORDER_TOP_ONLY,
            row = panel_row(),
            col = 0,
            width = vim.o.columns,
            height = panel_rows(),
          })
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
