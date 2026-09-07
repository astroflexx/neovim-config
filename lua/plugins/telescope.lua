-- opens `dir` as the new project root: changes cwd, clears out the old
-- project's file buffers (mirrors VSCode's "Open Folder"), then repoints
-- nvim-tree at the new root
local function open_folder(dir)
  vim.cmd.cd(dir)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  require("nvim-tree.api").tree.change_root(dir)
  require("nvim-tree.api").tree.open()
  require("core.empty_state").ensure()
end

-- <leader>j: fuzzy-search every folder under $HOME and open the picked one
-- as the project root (folders only, ~ only - not the whole filesystem)
local function search_and_open_folder()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local home = vim.fn.expand("~")
  local fd_bin = vim.fn.executable("fd") == 1 and "fd" or "fdfind"

  pickers
    .new({}, {
      prompt_title = "Search and Open Folder",
      finder = finders.new_oneshot_job({
        fd_bin,
        "--type", "d",
        "--max-depth", "6",
        "--exclude", "node_modules",
        "--exclude", "target",
        "--exclude", "build",
        "--exclude", "dist",
        "--exclude", "vendor",
        "--exclude", "__pycache__",
        "--exclude", "venv",
        ".",
        home,
      }, {
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry:gsub("^" .. vim.pesc(home), "~"),
            ordinal = entry,
          }
        end,
      }),
      sorter = conf.file_sorter({}),
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          return { "ls", "-la", "--color=always", entry.value }
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open_folder(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

-- pick the window the file should land in: a normal, non-floating window
-- that isn't nvim-tree or a terminal (mirrors empty_state's notion of the
-- "editor" window). falls back to the current window.
local function editor_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].buftype ~= "terminal" then
        return win
      end
    end
  end
  return vim.api.nvim_get_current_win()
end

-- open `path`: if its buffer is already visible in a window, just focus
-- that window; otherwise load it in the editor window (adds a bufferline
-- tab like any freshly opened buffer)
local function open_file(path)
  path = vim.fn.fnamemodify(path, ":p")

  local target
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b) == path then
      target = b
      break
    end
  end

  if target then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(win) == target then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  vim.api.nvim_set_current_win(editor_win())
  vim.cmd.edit(vim.fn.fnameescape(path))
end

-- <leader>k: fuzzy-search files under the current project root and open
-- the picked one (switching to it if it's already open)
local function search_and_open_file()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local cwd = vim.fn.getcwd()
  local fd_bin = vim.fn.executable("fd") == 1 and "fd" or "fdfind"

  pickers
    .new({}, {
      prompt_title = "Search and Open File",
      cwd = cwd,
      finder = finders.new_oneshot_job({
        fd_bin,
        "--type", "f",
        "--hidden",
        "--exclude", ".git",
        "--exclude", "node_modules",
      }, {
        cwd = cwd,
        entry_maker = function(line)
          return {
            value = line,
            display = line,
            ordinal = line,
            path = cwd .. "/" .. line,
          }
        end,
      }),
      sorter = conf.file_sorter({}),
      -- plain cat/bat preview instead of the built-in buffer previewer,
      -- which trips over a telescope/treesitter version mismatch
      -- (previewers/utils.lua: ft_to_lang nil)
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          local bat = vim.fn.executable("bat") == 1 and "bat"
            or vim.fn.executable("batcat") == 1 and "batcat"
          if bat then
            return { bat, "--style=plain", "--color=always", "--paging=never", entry.path }
          end
          return { "cat", entry.path }
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open_file(selection.path)
          end
        end)
        return true
      end,
    })
    :find()
end

return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Telescope",
  keys = {
    { "<leader>k", search_and_open_file, desc = "Search and open file" },
    { "<leader>j", search_and_open_folder, desc = "Search and open folder" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        scroll_strategy = "limit", -- stop at the first/last result instead of wrapping around
        mappings = {
          i = {
            ["kj"] = { "<Esc>", type = "command" },
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
        },
      },
    })
  end,
}
