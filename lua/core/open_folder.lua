-- open_folder.lua: switch the project root to `dir`, mirroring VSCode's
-- "Open Folder" - change cwd, wipe the old project's file buffers, restore
-- that folder's session (persistence.nvim) if it has one, repoint nvim-tree,
-- and land the cursor in the editor window.
--
-- shared by the <leader>j picker (lua/plugins/telescope.lua), the dashboard
-- shortcuts (lua/plugins/dashboard.lua) and the `nvim <dir>` startup path
-- (lua/plugins/nvim-tree.lua).

local M = { current = nil }

local function first_editor_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "NvimTree" and vim.api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
end

local function focus_editor_win()
  local win = first_editor_win()
  if win then
    vim.api.nvim_set_current_win(win)
  end
end

-- prune buffers that shouldn't be in a project:
--   mode "all"   - every listed file buffer (the "close the old project" pass)
--   mode "junk"  - directory buffers (`nvim <dir>`) and buffers pointing at a
--                  path that doesn't exist (stale session entries)
local function wipe_buffers(mode)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      local listed_file = vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
      local is_dir = name ~= "" and vim.fn.isdirectory(name) == 1
      local missing = listed_file and name ~= "" and vim.fn.filereadable(name) == 0 and not is_dir
      if is_dir or (mode == "all" and listed_file) or (mode == "junk" and missing) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

local function has_real_buffer()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then
      return true
    end
  end
  return false
end

-- is there a saved session on disk for the current cwd?
local function session_exists()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return false
  end
  local f = persistence.current()
  return type(f) == "string" and vim.fn.filereadable(f) == 1
end

-- write the session for the folder we're currently in. called before we cd
-- away; the exit save is handled by persistence's own VimLeavePre hook.
function M.save()
  pcall(function()
    require("nvim-tree.api").tree.close()
  end)
  pcall(function()
    require("persistence").save()
  end)
end

function M.open(dir)
  dir = vim.fn.fnamemodify(vim.fn.expand(dir), ":p"):gsub("(.)/$", "%1")
  if vim.fn.isdirectory(dir) == 0 then
    vim.notify("open folder: not a directory: " .. dir, vim.log.levels.WARN)
    return
  end

  if M.current == dir then
    require("nvim-tree.api").tree.focus()
    return
  end

  -- persist the folder we're leaving, if we had one open (cwd is still the
  -- old one here). skipped at startup, where nothing was opened yet.
  if M.current then
    M.save()
  end

  focus_editor_win()
  vim.cmd.cd(dir)

  wipe_buffers("all") -- close the previous project (VSCode "Open Folder")

  -- persistence.load() sources the session: badd's every saved buffer in
  -- order and edits the one that was active, in the current window.
  if session_exists() then
    pcall(function()
      require("persistence").load()
    end)
    wipe_buffers("junk") -- drop dir buffers / stale entries a session re-added
  end

  pcall(function()
    require("nvim-tree.api").tree.open()
    require("nvim-tree.api").tree.change_root(dir)
  end)
  require("core.empty_state").ensure() -- no-op when a session restored buffers

  M.current = dir
  if not M.started then
    -- arm persistence's VimLeavePre auto-save now that a real project is open
    pcall(function()
      require("persistence").start()
    end)
    M.started = true
  end

  -- land the cursor in the editor window, not the tree (after empty_state's
  -- own deferred ensure() has had a chance to create the placeholder window)
  vim.schedule(focus_editor_win)
end

return M
