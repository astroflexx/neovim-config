-- msg_timeout.lua auto-clears the command-line message area (":w written",
-- "5 lines yanked", lint/format results, etc.) a few seconds after it stops
-- changing, instead of letting it sit there until the next message
-- overwrites it.

local M = {}

local TIMEOUT_MS = 3000
local POLL_MS = 500

local last_msg = ""
local last_change = vim.uv.now()

local function tick()
  local msg = vim.v.statusmsg or ""
  if msg ~= last_msg then
    last_msg = msg
    last_change = vim.uv.now()
    return
  end

  if msg == "" then return end
  if vim.uv.now() - last_change < TIMEOUT_MS then return end
  if vim.api.nvim_get_mode().mode ~= "n" then return end

  vim.api.nvim_echo({ { "", "" } }, false, {})
  vim.v.statusmsg = ""
  last_msg = ""
end

-- vim.notify (used by nvim-tree and other plugins) goes through nvim_echo
-- but never touches v:statusmsg, so the polling above never sees it. Wrap
-- it directly and time its clear from the moment it's shown; a generation
-- counter stops an older notification's timer from wiping a newer one.
local generation = 0

local function wrap_notify()
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    orig_notify(msg, level, opts)
    generation = generation + 1
    local my_generation = generation
    vim.defer_fn(function()
      if my_generation ~= generation then return end
      if vim.api.nvim_get_mode().mode ~= "n" then return end
      vim.api.nvim_echo({ { "", "" } }, false, {})
    end, TIMEOUT_MS)
  end
end

function M.setup()
  local timer = vim.uv.new_timer()
  timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(tick))
  wrap_notify()
end

return M
