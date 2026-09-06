-- dashboard.lua sets up the start screen shown when nvim is opened with no file

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
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
          { section = "startup" },
        },
      },
    },
    config = function(_, opts)
      -- hide the terminal cursor while the dashboard is shown; it starts
      -- at 1,0 (top-left) and looks like a stray block on the empty screen
      local group = vim.api.nvim_create_augroup("dashboard_cursor", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "snacks_dashboard",
        callback = function(ev)
          io.write("\27[?25l")
          vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave", "BufDelete" }, {
            group = group,
            buffer = ev.buf,
            once = true,
            callback = function()
              io.write("\27[?25h")
            end,
          })
        end,
      })
      require("snacks").setup(opts)
    end,
  },
}
