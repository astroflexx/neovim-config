-- msg_timeout.lua auto-clears the command-line message area (":w written",
-- "5 lines yanked", lint/format results, etc.) a few seconds after it stops
-- changing, instead of letting it sit there until the next message
-- overwrites it.

local M = {}

local TIMEOUT_MS = 3000
local POLL_MS = 500

local last_msg = ""
local last_change = vim.uv.now()

-- only actually typing a ":" command is unsafe to clear over; insert/visual/
-- normal are all fine, and if we do land on "c" we just retry shortly after
-- instead of giving up on the clear entirely
local function clear_msg(on_done)
  if vim.api.nvim_get_mode().mode == "c" then
    vim.defer_fn(function() clear_msg(on_done) end, 200)
    return
  end
  vim.api.nvim_echo({ { "", "" } }, false, {})
  if on_done then on_done() end
end

local function tick()
  local msg = vim.v.statusmsg or ""
  if msg ~= last_msg then
    last_msg = msg
    last_change = vim.uv.now()
    return
  end

  if msg == "" then return end
  if vim.uv.now() - last_change < TIMEOUT_MS then return end

  clear_msg(function()
    vim.v.statusmsg = ""
    last_msg = ""
  end)
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
      clear_msg()
    end, TIMEOUT_MS)
  end
end

function M.setup()
  local timer = vim.uv.new_timer()
  timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(tick))
  wrap_notify()
end

return M
