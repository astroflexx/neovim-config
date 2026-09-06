-- keymaps.lua is to set global keymappings

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- use "kj" to switch from any mode to normal mode
map("i", "kj", "<Esc>")
map("v", "kj", "<Esc>")
map("c", "kj", "<Esc>")

map("n", "<leader>q", "<cmd>qa<cr>")

-- <leader>n: new unnamed buffer, save with :w <filename>
map("n", "<leader>n", "<cmd>enew<cr>")

-- <leader>e: focus the editor from anywhere - the file tree, a terminal, a
-- dap-ui panel. Jumps to the first normal file window in the tab.
map("n", "<leader>e", function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if (vim.bo[buf].buftype == "" or require("core.empty_state").is_empty_buf(buf)) and vim.bo[buf].filetype ~= "NvimTree" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.notify("no editor window to focus", vim.log.levels.WARN)
end)

-- lsp navigation
map("n", "<leader>gd", "<C-]>")
map("n", "<leader>gs", "<C-w>]")
map("n", "<leader>gp", "<C-w>}")
-- debug (see lua/plugins/dap.lua): <leader>i start/stop, <leader>b breakpoint,
-- <leader>, continue. mid-session, <leader>v/w/l/t focus panels and <leader>r
-- restarts (normal meanings restored on teardown).
-- diagnostics float on <leader>c
map("n", "<leader>c", vim.diagnostic.open_float)
map("n", "<leader>s", vim.lsp.buf.signature_help)

-- <leader>m: drop search highlight and wipe the command line
map("n", "<leader>m", function()
  vim.cmd("nohlsearch")
  vim.cmd("echo ''")
end)

-- <leader>y: yank the whole buffer to the system clipboard (like :%y+)
map("n", "<leader>y", function()
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("not a file buffer, can't yank", vim.log.levels.ERROR)
    return
  end
  vim.cmd('%yank +')
  local lines = vim.api.nvim_buf_line_count(0)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
  vim.notify(string.format("yanked %d line%s from %s", lines, lines == 1 and "" or "s", name))
end)
map("n", "<leader>x", function()
  local bt = vim.bo.buftype
  local ft = vim.bo.filetype
  local empty_state = require("core.empty_state")

  if ft == "NvimTree" then
    require("nvim-tree.api").tree.close()
    local bufs = vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
    if #bufs == 0 then vim.cmd("qa") end
  elseif empty_state.is_empty_buf(vim.api.nvim_get_current_buf()) then
    -- nothing real to close
  elseif bt == "" then
    local tree_open = false
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
        tree_open = true
        break
      end
    end
    local buf_to_delete = vim.api.nvim_get_current_buf()
    if vim.bo[buf_to_delete].modified then
      local name = vim.api.nvim_buf_get_name(buf_to_delete)
      name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
      if not require("core.confirm").ask(" Close buffer ", '"' .. name .. '" has unsaved changes.') then
        return
      end
    end
    vim.cmd("bprevious")
    if vim.api.nvim_get_current_buf() == buf_to_delete and not tree_open then
      -- with the tree open, empty_state.ensure() below replaces this
      -- window's buffer with the placeholder, so no need for a scratch
      -- buffer here
      vim.cmd("enew")
    end
    vim.cmd("bdelete! " .. buf_to_delete)
    local bufs = vim.tbl_filter(function(b)
      return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted
    end, vim.api.nvim_list_bufs())
    local only_empty = #bufs == 0 or (#bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" and not vim.bo[bufs[1]].modified)
    if only_empty and not tree_open then
      vim.cmd("qa")
    end
    -- if the tree is open, the empty_state autocmd fills the editor
    -- window with a placeholder instead of letting the tree go full-width
  else
    vim.cmd("q")
  end
end)
