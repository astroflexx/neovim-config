-- tree_state.lua: remember nvim-tree's per-folder state (expanded folders +
-- the dotfiles/H toggle) alongside the persistence.nvim session. the session
-- itself deliberately drops the tree window (see plugins/persistence.lua), so
-- this sits in a sidecar json next to the session file.
--
-- save() runs on PersistenceSavePre (exit + folder switch); restore() is
-- called by core/open_folder once the tree is open on the new root.

local M = {}

-- <session>.vim -> <session>.tree.json (both keyed by cwd)
local function state_file()
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    return nil
  end
  return (persistence.current():gsub("%.vim$", ".tree.json"))
end

local function explorer()
  local ok, core = pcall(require, "nvim-tree.core")
  return ok and core.get_explorer() or nil
end

function M.save()
  local e, file = explorer(), state_file()
  if not e or not file then
    return
  end

  local open = {}
  local function walk(nodes)
    for _, node in ipairs(nodes or {}) do
      if node.open then
        table.insert(open, node.absolute_path)
        walk(node.nodes)
      end
    end
  end
  walk(require("nvim-tree.api").tree.get_nodes().nodes)

  local data = vim.json.encode({
    root = e.absolute_path,
    dotfiles = e.filters.state.dotfiles,
    open = open,
  })
  pcall(vim.fn.writefile, { data }, file)
end

function M.restore()
  local e, file = explorer(), state_file()
  if not e or not file then
    return
  end

  local data
  if vim.fn.filereadable(file) == 1 then
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
    data = ok and type(decoded) == "table" and decoded or nil
  end
  -- folder without a saved tree (or saved under a different root): fall back
  -- to the configured default so the previous project's H toggle doesn't leak
  if not data or data.root ~= e.absolute_path then
    data = { dotfiles = require("nvim-tree.api").config.user().filters.dotfiles ~= false, open = {} }
  end

  if e.filters.state.dotfiles ~= data.dotfiles then
    e.filters.state.dotfiles = data.dotfiles
    e:reload_explorer()
  end

  local open = {}
  for _, path in ipairs(data.open or {}) do
    open[path] = true
  end
  if next(open) then
    e:expand({
      expand_until = function(_, node)
        return open[node.absolute_path] == true
      end,
    })
  end
end

return M
