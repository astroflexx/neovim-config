local open_folder = require("core.open_folder").open

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

local function bat_bin()
  return vim.fn.executable("bat") == 1 and "bat"
    or vim.fn.executable("batcat") == 1 and "batcat"
    or nil
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

-- drop the current buffer's bufferline tab immediately to the right of
-- `origin_buf`. new buffers otherwise slot in by buffer number, which lands
-- a re-listed old buffer in the middle of the row instead of next to the
-- file you opened it from.
local function place_tab_after(origin_buf, cur, tries)
  local ok, state = pcall(require, "bufferline.state")
  if not ok or not state.components then
    return
  end
  local from, o
  for i, c in ipairs(state.components) do
    if c.id == cur then
      from = i
    end
    if c.id == origin_buf then
      o = i
    end
  end
  -- bufferline rebuilds `components` on its own redraw tick, so the freshly
  -- opened buffer may not be in the list yet - retry a couple of times.
  if not from and (tries or 0) < 5 then
    vim.defer_fn(function()
      place_tab_after(origin_buf, cur, (tries or 0) + 1)
    end, 20)
    return
  end
  if not from or not o or from == o then
    return
  end
  -- bufferline's move_to is a swap, not an insert, so bubble the tab one slot
  -- at a time (move() swaps with the neighbour) until it sits just after the
  -- origin: o - from steps right if it started left of the origin, else
  -- from - o - 1 steps left.
  local steps = from < o and (o - from) or -(from - o - 1)
  local dir = steps > 0 and 1 or -1
  local move = require("bufferline.commands").move
  for _ = 1, math.abs(steps) do
    pcall(move, dir)
  end
end

-- open `path`: if its buffer is already visible in a window, just focus
-- that window; otherwise load it in the editor window, as a bufferline tab
-- placed right after the buffer it was opened from
local function open_file(path)
  path = vim.fn.fnamemodify(path, ":p")
  local origin = vim.api.nvim_get_current_buf()

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
  local opened = vim.api.nvim_get_current_buf()
  if opened ~= origin then
    vim.schedule(function()
      place_tab_after(origin, opened)
    end)
  end
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

  -- shared fd flags: hidden files in, VCS/dep dirs and common binary
  -- artifacts out (globs still leak extensionless compiled binaries,
  -- which the executable subtraction below strips)
  local fd_flags = table.concat({
    "--hidden",
    "--exclude .git",
    "--exclude node_modules",
    "--exclude '*.o' --exclude '*.obj' --exclude '*.a' --exclude '*.so'",
    "--exclude '*.dll' --exclude '*.dylib' --exclude '*.class' --exclude '*.pyc'",
    "--exclude '*.pdf' --exclude '*.png' --exclude '*.jpg' --exclude '*.jpeg'",
    "--exclude '*.gif' --exclude '*.ico' --exclude '*.zip' --exclude '*.gz'",
    "--exclude '*.tar' --exclude '*.exe' --exclude '*.bin'",
  }, " ")

  -- list = regular files minus executables (comm -23), so ELF binaries
  -- like `a.out` / compiled `main` don't clutter the picker
  local list_cmd = string.format(
    "comm -23 <(%s --type f %s | LC_ALL=C sort) <(%s --type x %s | LC_ALL=C sort)",
    fd_bin, fd_flags, fd_bin, fd_flags
  )

  pickers
    .new({}, {
      prompt_title = "Search and Open File",
      cwd = cwd,
      finder = finders.new_oneshot_job({ "bash", "-c", list_cmd }, {
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
          local bat = bat_bin()
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

-- <leader>/: ripgrep live-grep the current buffer's file. the finder re-runs
-- rg on every keystroke; <cr> jumps the cursor to the matched line.
local function live_grep_buffer()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    vim.notify("live grep: current buffer isn't a file", vim.log.levels.WARN)
    return
  end
  file = vim.fn.fnamemodify(file, ":p")

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local entry_maker = function(line)
    local lnum, col, text = line:match("^(%d+):(%d+):(.*)$")
    if not lnum then
      return nil
    end
    lnum, col = tonumber(lnum), tonumber(col)
    return {
      value = line,
      ordinal = text,
      display = string.format("%4d  %s", lnum, text),
      lnum = lnum,
      col = col,
      path = file,
    }
  end

  pickers
    .new({}, {
      prompt_title = "Live Grep · " .. vim.fn.fnamemodify(file, ":t"),
      finder = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
          return nil
        end
        return {
          "rg", "--color=never", "--no-heading", "--no-filename",
          "--line-number", "--column", "--smart-case", "--", prompt, file,
        }
      end, entry_maker),
      sorter = sorters.highlighter_only({}),
      -- bat's own --highlight-line is theme-dependent and often invisible on
      -- dark themes, so instead render a context window and paint a muted grey
      -- background on the matched row ourselves (row N of the sliced output),
      -- extended to the window edge with \033[K - visible on any theme without
      -- the glare of reverse video.
      previewer = previewers.new_termopen_previewer({
        get_command = function(entry)
          local ctx = 20
          local lo = math.max(1, entry.lnum - ctx)
          local hi = entry.lnum + ctx
          local row = entry.lnum - lo + 1
          local bat = bat_bin()
          local src = bat
              and string.format(
                "%s --style=numbers --color=always --paging=never --line-range %d:%d %s",
                bat, lo, hi, vim.fn.shellescape(file)
              )
            or string.format("sed -n '%d,%dp' %s", lo, hi, vim.fn.shellescape(file))
          return {
            "bash", "-c",
            src .. string.format(
              " | awk '{sub(/\\r$/,\"\")} NR==%d{gsub(/\\033\\[[0-9;]*m/,\"\");printf \"\\033[48;5;238m%%s\\033[K\\033[0m\\n\",$0;next} {print}'",
              row
            ),
          }
        end,
      }),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not selection then
            return
          end
          open_file(selection.path)
          pcall(vim.api.nvim_win_set_cursor, 0, { selection.lnum, math.max(0, selection.col - 1) })
          vim.cmd("normal! zz")
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
    { "<leader>/", live_grep_buffer, desc = "Live grep current file" },
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
