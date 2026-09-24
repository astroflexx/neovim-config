-- drag_scroll.lua makes a mouse selection auto-scroll *upward*, the way it
-- already does downward.
--
-- Dragging past the bottom of a window scrolls on its own: the rows under the
-- text - the statusline, the command line - are still part of the screen, so
-- the pointer keeps landing outside the window and neovim scrolls down to
-- follow it. Above the window there is at most the tabline, and the terminal
-- clamps the pointer at screen row 1, so once the drag reaches the top the
-- events stop arriving and the selection stalls on the topmost visible line.
--
-- There is nothing left to react to, so drive it ourselves: while the pointer
-- rests on (or above) the window's first text row, a timer walks the cursor up
-- a line at a time. In visual mode that extends the selection and pulls the
-- viewport along - exactly what the downward drag does.

local M = {}

local INTERVAL_MS = 40 -- one step per tick, so ~25 lines a second
local MAX_STEP = 6 -- lines per tick, for a drag that ends far above the window

local timer = nil
local drag_win = nil

local function stop()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  drag_win = nil
end

-- screen row (1-based) of a window's first line of *text*: win_screenpos
-- already accounts for the tabline, the winbar sits inside the window
local function text_top(win)
  return vim.fn.win_screenpos(win)[1] + (vim.wo[win].winbar ~= "" and 1 or 0)
end

local function tick()
  if not (drag_win and vim.api.nvim_win_is_valid(drag_win)) then return stop() end
  if drag_win ~= vim.api.nvim_get_current_win() then return stop() end
  -- a drag that never selects anything - resizing on a window separator, say -
  -- stays in normal mode, and the selection is over once we leave visual
  if not vim.fn.mode():find("^[vVsS\22\19]") then return stop() end
  if vim.fn.line(".") == 1 then return stop() end -- nothing above to walk into

  -- push further past the top edge to scroll faster, like the downward drag
  local above = text_top(drag_win) - vim.fn.getmousepos().screenrow
  local step = math.min(1 + math.max(above, 0), MAX_STEP)
  -- 'wrap' is off config-wide, but a plugin window may turn it on; there gk
  -- keeps a step to one *screen* line, which is what the pointer measures in
  pcall(function()
    vim.cmd("normal! " .. step .. (vim.wo[drag_win].wrap and "gk" or "k"))
  end)
end

local function on_drag()
  local win = vim.api.nvim_get_current_win()
  if vim.fn.getmousepos().screenrow > text_top(win) then return stop() end

  drag_win = win
  if timer then return end
  timer = vim.uv.new_timer()
  timer:start(INTERVAL_MS, INTERVAL_MS, vim.schedule_wrap(tick))
end

function M.setup()
  -- <expr> maps: the built-in drag/release still runs, and the scheduled
  -- callback gets to look at where it left the cursor and the viewport
  vim.keymap.set({ "n", "v", "i" }, "<LeftDrag>", function()
    vim.schedule(on_drag)
    return "<LeftDrag>"
  end, { expr = true, desc = "mouse: auto-scroll up at the top of a window" })

  vim.keymap.set({ "n", "v", "i" }, "<LeftRelease>", function()
    stop()
    return "<LeftRelease>"
  end, { expr = true, desc = "mouse: stop auto-scrolling" })
end

return M
