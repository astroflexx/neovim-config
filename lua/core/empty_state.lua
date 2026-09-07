-- empty_state.lua keeps a placeholder "editor" window alive next to
-- nvim-tree whenever no real buffers are open, so the tree never expands
-- to fill the whole screen (matches the VSCode-style empty state).

local M = {}

local BUF_NAME = "NvimTreeEmpty"
local FILETYPE = "emptystate"

local function get_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match(BUF_NAME .. "$") then
      return b
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, BUF_NAME)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = FILETYPE
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "",
    "  No buffers open.",
    "",
    "  Open one from the file pane, or press <leader>k to find files.",
  })
  vim.bo[buf].modifiable = false
  return buf
end

function M.is_empty_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  return vim.api.nvim_buf_get_name(buf):match(BUF_NAME .. "$") ~= nil
end

local function is_blank(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if M.is_empty_buf(buf) then return true end
  return vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified
end

local function tree_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return win
    end
  end
  return nil
end

-- classify the non-tree windows in the current tab: is there one already
-- showing real content, and is there a spare blank window we can reuse?
local function scan_editor_wins()
  local blank_win, has_content = nil, false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= "NvimTree" then
      if is_blank(buf) then
        blank_win = blank_win or win
      else
        has_content = true
      end
    end
  end
  return blank_win, has_content
end

-- if nvim-tree has no real editor window next to it in the current tab,
-- open (or reuse) a placeholder window so the tree keeps its fixed width
-- instead of expanding to fill the whole screen.
function M.ensure()
  vim.schedule(function()
    local twin = tree_win()
    if not twin then return end

    local blank_win, has_content = scan_editor_wins()
    if has_content then return end

    if blank_win then
      local old_buf = vim.api.nvim_win_get_buf(blank_win)
      local placeholder = get_buf()
      vim.api.nvim_win_set_buf(blank_win, placeholder)
      -- Vim's own "no buffer left" fallback leaves a throwaway [No Name]
      -- buffer behind; wipe it so it doesn't linger as a bufferline tab
      if old_buf ~= placeholder and vim.api.nvim_buf_is_valid(old_buf) and not M.is_empty_buf(old_buf) and vim.api.nvim_buf_get_name(old_buf) == "" then
        pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
      end
      return
    end

    -- when nvim-tree hijacks the sole window (e.g. `nvim <dir>`) it takes
    -- on that window's full width rather than its configured width, so
    -- pin it back to the configured width once we give it a sibling
    local tree_width = vim.g.nvim_tree_view_width or vim.api.nvim_win_get_width(twin)
    vim.api.nvim_set_current_win(twin)
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, get_buf())
    vim.api.nvim_win_set_width(twin, tree_width)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "WinClosed" }, {
    callback = M.ensure,
  })
end

return M
