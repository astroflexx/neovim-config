-- dashboard.lua sets up the start screen shown when nvim is opened with no file

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
        width = 50, -- matches the header art's display width so rows align to it exactly
        preset = {
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        sections = {
          { section = "header" },
          { padding = 1 },
          {
            key = "j",
            desc = "Search and open folder",
            action = "<leader>j",
            padding = 1,
          },
          {
            key = "k",
            desc = "Search and open file",
            action = "<leader>k",
            padding = 1,
          },
          {
            key = "n",
            desc = "New scratch file",
            action = function()
              vim.cmd("enew")
              vim.b.keep_blank = true
              require("core.open_folder").current = vim.fn.getcwd()
              require("nvim-tree.api").tree.toggle({ focus = false, find_file = false })
            end,
            padding = 1,
          },
          {
            key = "p",
            desc = "Open ~/problem-solving",
            action = function()
              require("core.open_folder").open("~/problem-solving")
            end,
            padding = 1,
          },
          {
            key = "q",
            desc = "Quit",
            action = ":qa",
          },
          { padding = 1 },
          { section = "startup" },
          { padding = 12 }, -- pushes the whole block up from dead-center
        },
      },
    },
    config = function(_, opts)
      -- hide the terminal cursor while the dashboard is focused; it starts
      -- at 1,0 (top-left) and looks like a stray block on the empty screen.
      -- hide/show on every enter/leave (not one-shot) so it stays hidden
      -- after round-tripping through a picker (e.g. <leader>j then <leader>x)
      local group = vim.api.nvim_create_augroup("dashboard_cursor", { clear = true })
      vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter" }, {
        group = group,
        pattern = "*",
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "snacks_dashboard" then
            io.write("\27[?25l")
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave", "BufDelete" }, {
        group = group,
        pattern = "*",
        callback = function(ev)
          if vim.bo[ev.buf].filetype == "snacks_dashboard" then
            io.write("\27[?25h")
          end
        end,
      })

      -- disable mouse-wheel scrolling on the dashboard only; the header/menu
      -- is meant to stay fixed, unlike normal buffers which keep scrolling
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "snacks_dashboard",
        callback = function(ev)
          for _, wheel in ipairs({
            "<ScrollWheelUp>",
            "<ScrollWheelDown>",
            "<S-ScrollWheelUp>",
            "<S-ScrollWheelDown>",
            "<C-ScrollWheelUp>",
            "<C-ScrollWheelDown>",
          }) do
            vim.keymap.set({ "n", "i", "v" }, wheel, "<Nop>", { buffer = ev.buf })
          end
        end,
      })
      require("snacks").setup(opts)
    end,
  },
}
