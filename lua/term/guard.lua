-- Shared "is this terminal busy, and does the user really want to kill it?"
-- helper, used by both the ephemeral panel (plugins/toggleterm.lua) and the
-- persistent deck (term/deck.lua). Killing a terminal means losing whatever is
-- running in it, so anything past a bare shell prompt earns a confirmation.

local confirm = require("core.confirm")

local M = {}

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

function M.confirm_kill(names)
  local subject = #names == 1 and ('"' .. names[1] .. '" is')
    or (table.concat(vim.tbl_map(function(n) return '"' .. n .. '"' end, names), ", ") .. " are")
  return confirm.ask(" Kill terminal ", subject .. " still running in this terminal.")
end

-- Guard in front of a kill: true if the caller may proceed. Silent when the
-- shell is idle, a confirmation modal when a command is still running.
function M.may_kill(bufnr)
  local names = M.running_children(vim.b[bufnr].terminal_job_pid)
  if #names == 0 then return true end
  return M.confirm_kill(names)
end

return M
