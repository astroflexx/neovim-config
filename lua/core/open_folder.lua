-- open_folder.lua: switch the project root to `dir`, mirroring VSCode's
-- "Open Folder" - change cwd, wipe the old project's file buffers, repoint
-- nvim-tree, and land the cursor in the editor window (not the tree).
--
-- shared by the <leader>j picker (lua/plugins/telescope.lua) and the
-- dashboard shortcuts (lua/plugins/dashboard.lua).

local M = {}

function M.open(dir)
  dir = vim.fn.fnamemodify(vim.fn.expand(dir), ":p"):gsub("/$", "")
  if vim.fn.isdirectory(dir) == 0 then
    vim.notify("open folder: not a directory: " .. dir, vim.log.levels.WARN)
    return
  end

  vim.cmd.cd(dir)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  require("nvim-tree.api").tree.change_root(dir)
  require("nvim-tree.api").tree.open()
  require("core.empty_state").ensure()

  -- land the cursor in the editor window (the empty-state placeholder),
  -- not the tree - matches `nvim <dir>` from the shell. ensure() runs on
  -- vim.schedule, so defer past it.
  vim.schedule(function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "NvimTree" then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end)
end

return M
