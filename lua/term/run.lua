-- <leader>u: compile & run the current C/C++ file in the ephemeral panel.
--
-- This is the competitive-programming loop: compile with the same warning set
-- every time, and only get to run the binary if the build was perfectly clean.
--
--   g++ -std=c++23 -O2 -Wall -Wextra -Wshadow <file>
--
-- Any compiler output at all - an error OR a bare warning - stops the flow at
-- the shell prompt with the diagnostics printed just above it. Read them, then
-- <leader>x to kill the panel (silent: the shell is idle). A build that emits
-- nothing falls through to ./a.out, which sits waiting for you to paste stdin;
-- close the panel yourself when you're done (guarded while a.out is running).
--
-- The command runs in whichever <leader>t panel is already open, or a fresh one
-- if none is. It assumes that panel is sitting idle at a prompt - if you fire
-- this while something else is running there, that's on you.

local M = {}

--- Compile the current C/C++ buffer and, if the build is warning- and
--- error-free, run ./a.out - all inside the ephemeral terminal panel.
function M.compile_and_run()
  local ft = vim.bo.filetype
  if (ft ~= "cpp" and ft ~= "c") or vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("not a C/C++ file, can't compile & run", vim.log.levels.ERROR)
    return
  end

  vim.cmd("silent! write")

  local dir = vim.fn.expand("%:p:h")
  local file = vim.fn.expand("%:t")
  local compiler = ft == "c" and "gcc" or "g++"
  local std = ft == "c" and "-std=c17" or "-std=c++23"

  -- stdout+stderr captured together: a non-empty capture means the build either
  -- failed or warned, and either way we stop rather than run. -fdiagnostics-
  -- color=always because inside $(...) the stream is a pipe, not a tty, so g++
  -- would otherwise drop the colour; printf '%s\n' re-emits the ANSI codes.
  local cmd = string.format(
    "cd %s && out=$(%s %s -O2 -Wall -Wextra -Wshadow -fdiagnostics-color=always %s 2>&1); "
      .. "if [[ -n \"$out\" ]]; then printf '%%s\\n' \"$out\"; else ./a.out; fi",
    vim.fn.shellescape(dir),
    compiler,
    std,
    vim.fn.shellescape(file)
  )

  local tt = require("toggleterm.terminal")
  local term = tt.get(1) or tt.Terminal:new({ id = 1 })

  if term:is_open() then
    term:send(cmd, false) -- false: keep focus in the terminal, ready for stdin
    return
  end

  -- A just-spawned shell is still sourcing its rc and drawing its first prompt.
  -- Sending into it then makes bash re-echo the line when the prompt finally
  -- lands, so the command shows up twice. Wait until the terminal buffer has
  -- stopped changing (prompt drawn and settled) before sending; poll rather
  -- than guess a fixed delay. Falls back to sending anyway after ~1.5s.
  term:open()
  local prev, stable = nil, 0
  local function try(attempt)
    if not (term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr)) then return end
    local now = table.concat(vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false), "\n")
    local drawn = now:gsub("%s", "") ~= ""
    stable = (drawn and now == prev) and (stable + 1) or 0
    prev = now
    if stable >= 2 or attempt >= 50 then
      term:send(cmd, false)
    else
      vim.defer_fn(function() try(attempt + 1) end, 30)
    end
  end
  vim.defer_fn(function() try(1) end, 30)
end

return M
