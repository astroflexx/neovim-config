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

return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Telescope",
  keys = {
    { "<leader>k", "<cmd>Telescope find_files<cr>", desc = "Find files" },
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
