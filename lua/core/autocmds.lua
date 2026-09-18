-- autocmds.lua is for attaching callback functions onto events
-- when you want any kind of action to happen after an event fires

-- remove alacritty padding immediately at load time (before first frame)
vim.fn.system({ "alacritty", "msg", "config", "window.padding.x=0" })
vim.api.nvim_create_autocmd("UILeave", {
  callback = function()
    vim.fn.system({ "alacritty", "msg", "config", "-r" })
  end,
})

-- restore last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- keep a placeholder editor window open next to nvim-tree so the tree
-- never expands to fill the whole screen when no buffers are open
require("core.empty_state").setup()

-- auto-clear command-line messages a few seconds after they stop changing
require("core.msg_timeout").setup()
