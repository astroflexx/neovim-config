-- Shared "is this terminal busy, and does the user really want to kill it?"
-- helper, used by both the ephemeral panel (plugins/toggleterm.lua) and the
-- persistent deck (term/deck.lua). Killing a terminal means losing whatever is
-- running in it, so anything past a bare shell prompt earns a confirmation.

local M = {}

-- "Kill terminal" title picks up the shell prompt's green: nvim exposes the 16
-- ANSI colours the terminal renders with as g:terminal_color_0..15. Re-applied
-- on ColorScheme since a theme swap redefines them.
local function set_hl()
  vim.api.nvim_set_hl(0, "TermKillTitle", {
    fg = vim.g.terminal_color_2 or vim.g.terminal_color_10 or "#6A9955",
    bold = true,
  })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = vim.schedule_wrap(set_hl) })

-- Names of a shell's direct child processes. An interactive shell sitting at
-- its prompt has none; a running command - or a backgrounded job - shows up
-- here. Linux-only: reads the kernel's per-task children list. Returns an empty
-- list on any other platform, or if the pid can't be inspected, so the caller
-- falls through to a silent kill rather than a spurious prompt.
function M.running_children(shell_pid)
  if not shell_pid then return {} end
  local fh = io.open(("/proc/%d/task/%d/children"):format(shell_pid, shell_pid), "r")
  if not fh then return {} end
  local ids = fh:read("*a") or ""
  fh:close()
  local names, seen = {}, {}
  for pid in ids:gmatch("%d+") do
    local cf = io.open("/proc/" .. pid .. "/comm", "r")
    if cf then
      local name = (cf:read("*l") or ""):gsub("%s+$", "")
      cf:close()
      if name ~= "" and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  return names
end

-- A small centred yes/no modal. Blocks until the user answers: `y` confirms,
-- `n` / `q` / <Esc> cancel, any other key is ignored. Returns true only on an
-- explicit yes.
function M.confirm_kill(names)
  local subject = #names == 1 and ('"' .. names[1] .. '" is')
    or (table.concat(vim.tbl_map(function(n) return '"' .. n .. '"' end, names), ", ") .. " are")
  local lines = {
    "",
    "  " .. subject .. " still running in this terminal.",
    "",
    "  Kill it anyway?    [y] yes    [n] no",
    "",
  }
  local width = 4
  for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l) + 2) end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " Kill terminal ",
    title_pos = "center",
    focusable = false,
    noautocmd = true,
    zindex = 250,
  })
  vim.wo[win].winhighlight = "NormalFloat:Normal,FloatBorder:WinSeparator,FloatTitle:TermKillTitle"
  vim.cmd("redraw")

  local answer
  while answer == nil do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then
      answer = false
    else
      ch = ch:lower()
      if ch == "y" then
        answer = true
      elseif ch == "n" or ch == "q" or ch == "\27" then
        answer = false
      end
    end
  end

  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  return answer
end

-- Guard in front of a kill: true if the caller may proceed. Silent when the
-- shell is idle, a confirmation modal when a command is still running.
function M.may_kill(bufnr)
  local names = M.running_children(vim.b[bufnr].terminal_job_pid)
  if #names == 0 then return true end
  return M.confirm_kill(names)
end

return M
