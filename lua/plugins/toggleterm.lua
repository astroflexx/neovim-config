-- Two terminals:
--   <leader>t / <C-\>   the panel  - a horizontal split under the editor, for
--                       quick throwaway work (see lua/term/panel.lua)
--   <leader>p           the deck   - a tabbed float for long-running jobs
--                       (see lua/term/deck.lua)
--
-- The panel is a real split, not a float: the editor window shrinks to the
-- space above it, so scrolling and `j`/`k` work normally while it is open. It
-- is re-parented in panel.on_open so the file tree keeps its full height.

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  -- The panel keys target terminal 1 explicitly so the deck's terminals (ids
  -- 101+) never get picked up by toggleterm's "first terminal" heuristic.
  keys = {
    -- <C-\> is the toggle from *inside* the terminal (insert mode): keeping
    -- <leader>t out of terminal mode means Space types instantly at the shell
    -- prompt instead of waiting `timeoutlen` for a possible <leader>t.
    { [[<C-\>]], function() require("term.panel").toggle() end, mode = { "n", "t" }, desc = "Toggle / focus terminal panel" },
    { "<leader>t", function() require("term.panel").toggle() end, desc = "Toggle / focus terminal panel" },
    { "<leader>p", function() require("term.deck").toggle() end, desc = "Toggle terminal deck" },
    { "<leader>u", function() require("term.run").compile_and_run() end, desc = "Compile & run current C/C++ file" },
  },
  cmd = { "ToggleTerm", "TermExec" },
  config = function()
    local terminal = require("toggleterm.terminal")
    local panel = require("term.panel")
    local guard = require("term.guard")

    require("toggleterm").setup({
      direction = "horizontal",
      size = function() return panel.height() end,
      -- always land in insert at the prompt when the panel is opened/focused,
      -- never in normal mode halfway up the scrollback
      persist_mode = false,
      persist_size = false,
      start_in_insert = true,
      close_on_exit = true,
      auto_scroll = true,
      shade_terminals = false,
      on_open = function(term)
        if term.id == panel.ID then panel.on_open(term) end
      end,
    })

    -- toggleterm force-closes any *floating* terminal the moment focus leaves
    -- it (`handle_term_leave` in toggleterm.lua calls `term:close()` on every
    -- float, with no setup opt-out) - that made a click / <leader>e into the
    -- editor yank the deck off screen. The handler's only other job was
    -- persisting mode, which we don't use (persist_mode = false), so just drop
    -- it. Intentional closes never went through WinLeave, so they still work.
    pcall(vim.api.nvim_clear_autocmds, { group = "ToggleTermCommands", event = "WinLeave" })

    -- Kill the panel the cursor is in: confirm first if a command is still
    -- running (term/guard.lua), then shut it down completely (window closed,
    -- buffer wiped, id freed). This is the only way to kill the panel - a plain
    -- <leader>t just hides it. Bails on anything that is not the panel.
    local function kill_panel()
      local _, term = terminal.identify()
      if not term or term.id ~= panel.ID then return end
      if not guard.may_kill(term.bufnr) then return end
      term:shutdown()
    end

    -- A neovim terminal buffer is padded with blank rows up to the window
    -- height, and vim scrolls down until the *last* line hits the top - so a
    -- fresh shell can be scrolled into a screenful of emptiness. Only let
    -- "scroll down" move while real content is still hidden below the viewport.
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
      local id = terminal.identify()
      local opts = { buffer = 0 }
      vim.keymap.set("t", "kj", [[<C-\><C-n>]], opts)
      vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)

      -- no over-scroll into blank space (<C-d>/<C-f> already clamp themselves)
      vim.keymap.set({ "n", "t" }, "<ScrollWheelDown>", scroll_down("3<C-e>"), opts)
      vim.keymap.set("n", "<C-e>", scroll_down("<C-e>"), opts)

      -- <leader>x kills the panel (guarded); buffer-local so it shadows the
      -- global <leader>x here. Deck tabs bind their own <leader>x in deck.lua.
      if id == panel.ID then
        vim.keymap.set("n", "<leader>x", kill_panel, opts)
      end
    end

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = set_terminal_keymaps,
    })
  end,
}
