-- dap.lua sets up debugging, the neovim equivalent of VSCode's "Run and Debug".
--
-- stack:
--   nvim-dap              - the debug engine / DAP client
--   nvim-dap-ui           - the VSCode-style panels (scopes, watches, stacks, repl)
--   nvim-dap-virtual-text - inline variable values next to the code, like VSCode
--   mason-nvim-dap        - installs the actual debug adapter (codelldb) via mason
--
-- codelldb is the adapter used for C, C++ and Rust. it's the same LLDB-based
-- backend the CodeLLDB VSCode extension uses. it ships STL pretty-printing out of
-- the box, and the integrated-terminal console lets you paste a test case
-- straight into the program's stdin - enough for competitive programming.
--
-- the build step mirrors the old VSCode tasks.json exactly:
--   g++ -fdiagnostics-color=always -g -std=c++23 <file> -o <fileDir>/<basename>
-- the binary is written next to the source, and a failed compile aborts the
-- session and shows the compiler output (preLaunchTask equivalent).

return {
  "mfussenegger/nvim-dap",
  event = "VeryLazy",
  dependencies = {
    {
      "rcarriga/nvim-dap-ui",
      dependencies = { "nvim-neotest/nvim-nio" },
    },
    "theHamsta/nvim-dap-virtual-text",
    {
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = { "mason-org/mason.nvim" },
      opts = {
        ensure_installed = { "codelldb" },
        automatic_installation = true,
        handlers = {},
      },
    },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    -- one-line status in the message area. <leader>i -> build -> launch has a
    -- noticeable pause; this keeps the user informed. `echo` (not notify) so a
    -- later message just overwrites it and it clears itself.
    local function status(msg)
      vim.api.nvim_echo({ { "debug: " .. msg, "MoreMsg" } }, false, {})
      vim.cmd("redraw")
    end

    -- set by start() when it auto-drops a breakpoint on main(); consumed by the
    -- build step so the two bits of info share one status line instead of one
    -- clobbering the other.
    local auto_bp_note = nil

    -- the buffer being debugged, pinned by start(). the build step must NOT read
    -- the "current" buffer: on restart, nvim-dap resolves program() while focus
    -- may be in a dap-ui panel or the tree.
    local target_buf = nil

    ----------------------------------------------------------------------------
    -- build step (VSCode preLaunchTask equivalent)
    ----------------------------------------------------------------------------

    -- compile the debugged C/C++ buffer and return the path to the executable.
    -- raises on failure so nvim-dap aborts the launch; the compiler output is
    -- surfaced via vim.notify.
    local function build_current_file()
      local buf = (target_buf and vim.api.nvim_buf_is_valid(target_buf)) and target_buf
        or vim.api.nvim_get_current_buf()
      local ft = vim.bo[buf].filetype
      if ft ~= "cpp" and ft ~= "c" then
        error("dap: current buffer is not a C/C++ file")
      end

      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! write")
      end)

      local path = vim.api.nvim_buf_get_name(buf)
      local file = vim.fn.fnamemodify(path, ":p")
      local out = vim.fn.fnamemodify(path, ":p:h") .. "/" .. vim.fn.fnamemodify(path, ":t:r")
      local compiler = ft == "c" and "gcc" or "g++"
      local std = ft == "c" and "-std=c17" or "-std=c++23"

      status("compiling" .. (auto_bp_note and ("  ·  " .. auto_bp_note) or "") .. "...")
      auto_bp_note = nil

      local output = vim.fn.system({
        compiler,
        "-fdiagnostics-color=always",
        "-g",
        std,
        file,
        "-o",
        out,
      })

      if vim.v.shell_error ~= 0 then
        status("build failed")
        vim.notify(output, vim.log.levels.ERROR, { title = "C/C++ build failed" })
        error("dap: build failed")
      end

      status("launching...")
      return out
    end

    ----------------------------------------------------------------------------
    -- launch configurations
    --
    -- the adapter itself ("codelldb") is registered for us by mason-nvim-dap.
    ----------------------------------------------------------------------------

    -- the default launch: build the current file and debug it. this is the only
    -- entry in dap.configurations so <leader>i never shows a picker.
    --
    -- stopOnEntry stays false: codelldb's "entry" is the process entry point
    -- (_start in the dynamic linker), not main - stopping there dumps you in
    -- disassembly. instead the <leader>i helper drops a breakpoint on main()
    -- automatically when you haven't set any, so a session always stops
    -- somewhere useful and the panel stays open.
    --
    -- console = "integratedTerminal" makes the bottom panel a real terminal: type
    -- or paste stdin there, see stdout there.
    local launch_current = {
      name = "C/C++: build & debug current file",
      type = "codelldb",
      request = "launch",
      program = build_current_file,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      console = "integratedTerminal",
    }

    dap.configurations.cpp = { launch_current }
    dap.configurations.c = { launch_current }

    ----------------------------------------------------------------------------
    -- UI: nvim-dap-ui + virtual text
    ----------------------------------------------------------------------------

    --------------------------------------------------------------------------
    -- custom "controls" element
    --
    -- dap-ui's built-in controls can only live in a window's winbar: one line,
    -- flush to the top edge, left-aligned. we want the play / step / stop
    -- buttons centered with breathing room above and below, so we render our
    -- own row into a dedicated element window at the top of the left panel.
    -- mouse=a is on, so the icons stay clickable (handled below).
    --------------------------------------------------------------------------

    local ctrl = {
      pad_above = 0, -- no blank padding - the row is the whole window
      pad_below = 0,
      width = 40, -- left panel width; used only for centering
      sep = "   ",
      buf = nil,
      click = {}, -- byte column (1-based, on the icon row) -> action
    }

    -- button order. "play" doubles as pause while the program is running.
    ctrl.buttons = {
      {
        key = "play",
        hl = "DapUIPlayPause",
        action = function()
          local s = dap.session()
          if not s or s.stopped_thread_id then
            dap.continue()
          else
            dap.pause()
          end
        end,
      },
      { key = "step_over", hl = "DapUIStepOver", action = function() dap.step_over() end },
      { key = "step_into", hl = "DapUIStepInto", action = function() dap.step_into() end },
      { key = "step_out", hl = "DapUIStepOut", action = function() dap.step_out() end },
      { key = "run_last", hl = "DapUIRestart", action = function() dap.run_last() end },
      { key = "terminate", hl = "DapUIStop", action = function() dap.terminate() end },
    }

    local ctrl_ns = vim.api.nvim_create_namespace("dap_controls_bar")

    -- create the buffer eagerly (plain sync context) so the element's
    -- buffer() accessor - which dap-ui may call from an async context - only
    -- ever has to hand back an existing handle.
    local function ctrl_new_buffer()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "hide"
      vim.bo[buf].swapfile = false
      vim.bo[buf].modifiable = false
      -- bufferline keys its left offset on this filetype (see bufferline.lua)
      vim.bo[buf].filetype = "dapui_controls"
      -- click dispatch: only the icon row, only within our buffer.
      vim.keymap.set("n", "<LeftRelease>", function()
        local pos = vim.fn.getmousepos()
        if pos.winid == 0 or not vim.api.nvim_win_is_valid(pos.winid) then
          return
        end
        if vim.api.nvim_win_get_buf(pos.winid) ~= ctrl.buf then
          return
        end
        if pos.line ~= ctrl.pad_above + 1 then
          return
        end
        local action = ctrl.click[pos.column]
        if action then
          action()
        end
      end, { buffer = buf, desc = "debug: click control button" })
      return buf
    end

    ctrl.buf = ctrl_new_buffer()

    local function ctrl_buffer()
      if not (ctrl.buf and vim.api.nvim_buf_is_valid(ctrl.buf)) then
        ctrl.buf = ctrl_new_buffer()
      end
      return ctrl.buf
    end

    local function ctrl_render()
      vim.schedule(function()
        local buf = ctrl_buffer()
        local icons = require("dapui.config").controls.icons
        local session = dap.session()
        local running = session and not session.stopped_thread_id

        local segs = {}
        for _, b in ipairs(ctrl.buttons) do
          if b.key == "play" then
            segs[#segs + 1] = running and icons.pause or icons.play
          else
            segs[#segs + 1] = icons[b.key]
          end
        end

        local body = table.concat(segs, ctrl.sep)
        local pad = math.max(0, math.floor((ctrl.width - vim.fn.strdisplaywidth(body)) / 2))
        local icon_row = string.rep(" ", pad) .. body

        -- byte column -> action, plus highlight ranges, for each icon
        ctrl.click = {}
        local hls, col = {}, pad -- col: 0-based byte offset into icon_row
        for i, icon in ipairs(segs) do
          local nbytes = #icon
          for c = col + 1, col + nbytes do
            ctrl.click[c] = ctrl.buttons[i].action
          end
          hls[#hls + 1] = { ctrl.buttons[i].hl, col, col + nbytes }
          col = col + nbytes + #ctrl.sep
        end

        local lines = {}
        for _ = 1, ctrl.pad_above do
          lines[#lines + 1] = ""
        end
        lines[#lines + 1] = icon_row
        for _ = 1, ctrl.pad_below do
          lines[#lines + 1] = ""
        end

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false

        vim.api.nvim_buf_clear_namespace(buf, ctrl_ns, 0, -1)
        for _, h in ipairs(hls) do
          pcall(vim.api.nvim_buf_set_extmark, buf, ctrl_ns, ctrl.pad_above, h[2], {
            end_col = h[3],
            hl_group = h[1],
          })
        end

        -- dap-ui sizes elements as a fraction of the column; pin this one to
        -- exactly the rows it needs so it doesn't hog space. also kill
        -- cursorline (on globally) - otherwise it paints a grey bar across
        -- the blank padding row the cursor sits on.
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then
            pcall(vim.api.nvim_win_set_height, win, #lines)
            vim.wo[win].cursorline = false
            vim.wo[win].cursorcolumn = false
            vim.wo[win].colorcolumn = ""
          end
        end
      end)
    end

    -- keep the play/pause icon in sync with session state
    for _, event in ipairs({
      "event_initialized", "event_stopped", "event_continued",
      "event_terminated", "event_exited",
    }) do
      dap.listeners.after[event]["dap_controls_bar"] = ctrl_render
    end

    dapui.setup({
      -- our own centered button row replaces dap-ui's winbar controls.
      controls = { enabled = false },
      -- in the variables + watch panels, "o" expands / collapses a node like
      -- <CR>. scoped to those elements, and we drop "o" from the "open" action
      -- there (globally "o" = open) so it doesn't double-bind / flash "No open
      -- action for current line".
      element_mappings = {
        scopes = {
          expand = { "<CR>", "o", "<2-LeftMouse>" },
          open = {},
        },
        watches = {
          expand = { "<CR>", "o", "<2-LeftMouse>" },
          open = {},
        },
      },
      -- keep long C++ type strings (std::_Vector_base<...>) and multi-line
      -- values from spilling out of the narrow left panel - truncate with an
      -- ellipsis instead.
      render = {
        indent = 1,
        max_type_length = 20,
        max_value_lines = 3,
      },
      layouts = {
        {
          -- left panel - replaces the file tree at the same width.
          -- CONTROLS row on top, then VARIABLES / WATCH / BREAKPOINTS. no call stack.
          position = "left",
          size = 40,
          elements = {
            -- controls is pinned to a fixed row count in ctrl_render; this
            -- fraction is just its starting guess before the first render.
            { id = "controls", size = 0.05 },
            { id = "scopes", size = 0.46 },
            { id = "watches", size = 0.28 },
            { id = "breakpoints", size = 0.21 },
          },
        },
        {
          -- bottom panel - the program terminal: paste stdin, read stdout.
          position = "bottom",
          size = 18,
          elements = {
            { id = "console", size = 1.0 },
          },
        },
      },
    })

    dapui.register_element("controls", {
      render = ctrl_render,
      buffer = ctrl_buffer,
      allow_without_session = true,
    })

    require("nvim-dap-virtual-text").setup({
      commented = true, -- render the inline values as trailing comments
      -- clamp the inline annotation so a big container value doesn't stretch
      -- a code line off the right edge of the screen.
      display_callback = function(variable, _buf, _stackframe, _node, options)
        local value = variable.value:gsub("%s+", " ")
        local max = 40
        if #value > max then
          value = value:sub(1, max - 1) .. "…"
        end
        if options.virt_text_pos == "inline" then
          return " = " .. value
        end
        return variable.name .. " = " .. value
      end,
    })

    --------------------------------------------------------------------------
    -- hide the block cursor in the variables + breakpoints panels - the
    -- cursorline (white bar) already shows the position there. the TUI paints
    -- the block using its highlight group's colours, so we point 'guicursor'
    -- at a group whose fg/bg both match the CursorLine background: the block
    -- melts into the bar. restored on leaving the panel.
    --------------------------------------------------------------------------
    local function refresh_hidden_cursor()
      local cl = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
      local bg = cl.bg or vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
      if bg then
        vim.api.nvim_set_hl(0, "DapHiddenCursor", { fg = bg, bg = bg })
      end
    end
    vim.api.nvim_create_autocmd("ColorScheme", { callback = refresh_hidden_cursor })

    local cursorless_ft = { dapui_scopes = true, dapui_breakpoints = true }
    local guicursor_saved
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      callback = function()
        if cursorless_ft[vim.bo.filetype] then
          refresh_hidden_cursor() -- recompute in case the colour wasn't ready earlier
          guicursor_saved = guicursor_saved or vim.o.guicursor
          vim.o.guicursor = "a:DapHiddenCursor"
          vim.wo.cursorline = true
        elseif guicursor_saved then
          vim.o.guicursor = guicursor_saved
          guicursor_saved = nil
        end
      end,
    })

    -- open / close the UI automatically around a session, like VSCode.
    -- while a session is running, hide nvim-tree so the dap-ui left panel takes
    -- over the space, then bring the tree back afterwards.
    --
    -- on teardown the cursor must land back in the buffer the session was
    -- started from - not in nvim-tree (which grabs focus when reopened) and not
    -- in a leftover dap-ui window. we remember the origin buffer on init and
    -- jump to a window showing it once the panels are gone.
    local tree_was_open = false
    local origin_buf = nil

    local function hide_tree()
      local ok, view = pcall(require, "nvim-tree.view")
      tree_was_open = ok and view.is_visible()
      if tree_was_open then
        require("nvim-tree.api").tree.close()
      end
    end

    local function restore_tree()
      if tree_was_open then
        pcall(function()
          require("nvim-tree.api").tree.open()
        end)
        tree_was_open = false
      end
    end

    -- put the cursor back where debugging started from.
    local function restore_focus()
      if not (origin_buf and vim.api.nvim_buf_is_valid(origin_buf)) then
        return
      end
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == origin_buf then
          pcall(vim.api.nvim_set_current_win, win)
          return
        end
      end
    end

    -- Static / Global / Registers scopes are noise for competitive programming
    -- (only Local matters), so start them collapsed - with no flash of them
    -- open first. dap-ui's scopes component auto-folds any scope the adapter
    -- marks `expensive`, so we tag those three `expensive` on the FIRST scopes
    -- response of each session, before dap-ui's `after` listener sees it. only
    -- the first response: after that the user's manual expand/collapse sticks
    -- (the component only ever force-folds, never force-opens).
    local noisy_scopes = { Static = true, Global = true, Registers = true }
    local folded_this_session = false
    dap.listeners.before["scopes"]["dap_fold_noisy_scopes"] = function(_, err, response)
      if folded_this_session or err or not (response and response.scopes) then
        return
      end
      folded_this_session = true
      for _, scope in ipairs(response.scopes) do
        if noisy_scopes[scope.name] then
          scope.expensive = true
        end
      end
    end

    local function teardown()
      dapui.close()
      restore_tree()
      folded_this_session = false
      -- defer so nvim-tree's own focus-on-open has already run
      vim.schedule(restore_focus)
    end

    dap.listeners.after.event_initialized["dapui_config"] = function()
      origin_buf = (target_buf and vim.api.nvim_buf_is_valid(target_buf))
        and target_buf or vim.api.nvim_get_current_buf()
      hide_tree()
      dapui.open()
      ctrl_render()
      status("session started")
    end
    dap.listeners.before.event_terminated["dapui_config"] = teardown
    dap.listeners.before.event_exited["dapui_config"] = teardown

    ----------------------------------------------------------------------------
    -- gutter signs
    ----------------------------------------------------------------------------

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "✘", texthl = "DiagnosticWarn" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })

    ----------------------------------------------------------------------------
    -- keymaps
    --
    --   <leader>i   start / stop the session
    --   <leader>,   continue (mid-session only)
    --   <leader>o   step over
    --   <leader>b   toggle breakpoint
    --   <leader>.   clear all breakpoints
    --   <leader>dr  restart (full: terminate -> rebuild -> fresh panels)
    --   <leader>de  jump focus back to the editor
    --   <leader>dv/dw/db/dt   focus the variables / expressions / breakpoints /
    --                         terminal panel
    --
    -- step into / out, pause, restart also live on the clickable DEBUG button
    -- bar at the top of the left panel.
    ----------------------------------------------------------------------------

    local map = vim.keymap.set
    local function d(desc)
      return { desc = "debug: " .. desc }
    end

    -- jump the cursor into a dap-ui panel by its buffer filetype
    local function focus_panel(ft, label)
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then
          vim.api.nvim_set_current_win(win)
          return
        end
      end
      vim.notify("debug: " .. label .. " panel isn't open", vim.log.levels.WARN)
    end

    -- jump back to the editor from any panel: prefer the buffer the session
    -- was started from, else the first normal file window.
    local function focus_editor()
      if origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == origin_buf then
            vim.api.nvim_set_current_win(win)
            return
          end
        end
      end
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(win)
        if vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "NvimTree" then
          vim.api.nvim_set_current_win(win)
          return
        end
      end
    end

    local function has_breakpoints()
      for _, bufbps in pairs(require("dap.breakpoints").get()) do
        if #bufbps > 0 then
          return true
        end
      end
      return false
    end

    -- start a session; if it's already running just continue. when no breakpoints
    -- are set, drop one on main() first so the run always stops instead of
    -- flashing past. `keep_target` reuses the previously-debugged buffer (used by
    -- restart, where focus may no longer be on the code).
    local function start(config, keep_target)
      if dap.session() then
        dap.continue()
        return
      end
      if not (keep_target and target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
        target_buf = vim.api.nvim_get_current_buf()
      end
      if not has_breakpoints() then
        local win = vim.fn.bufwinid(target_buf)
        if win ~= -1 then
          local cursor = vim.api.nvim_win_get_cursor(win)
          for i, line in ipairs(vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)) do
            if line:match("%f[%a]main%s*%(") then
              vim.api.nvim_win_set_cursor(win, { i, 0 })
              dap.toggle_breakpoint()
              vim.api.nvim_win_set_cursor(win, cursor)
              -- picked up by build_current_file() and shown alongside "compiling"
              auto_bp_note = "no breakpoints set, added one at main()"
              break
            end
          end
        end
      end
      status("starting...")
      dap.run(config)
    end

    -- <leader>i: no session -> start; running session -> terminate.
    map("n", "<leader>i", function()
      if dap.session() then
        dap.terminate()
      else
        start(launch_current)
      end
    end, d("start / stop session"))

    -- continue only makes sense mid-session; without this guard dap.continue()
    -- would kick off a brand-new session (and its config picker).
    map("n", "<leader>,", function()
      if dap.session() then
        dap.continue()
      else
        vim.notify("debug: no active session", vim.log.levels.WARN)
      end
    end, d("continue"))
    map("n", "<leader>o", dap.step_over, d("step over"))

    -- breakpoints
    map("n", "<leader>b", dap.toggle_breakpoint, d("toggle breakpoint"))
    map("n", "<leader>.", dap.clear_breakpoints, d("clear all breakpoints"))

    -- dap.restart() with codelldb sends a bare `restart` request: it reruns the
    -- STALE binary (our build step never re-fires) and leaves the panels /
    -- terminal from the old run on screen. do a real restart instead - fully
    -- terminate, let teardown close everything, then start() again (which
    -- rebuilds, reopens fresh panels and a fresh terminal).
    map("n", "<leader>dr", function()
      if not dap.session() then
        status("no session to restart")
        return
      end
      status("restarting...")
      dap.terminate(nil, nil, function()
        vim.schedule(function()
          start(launch_current, true) -- keep debugging the same buffer
        end)
      end)
    end, d("restart (rebuild + fresh panels)"))

    -- focus panels / jump back to the editor
    map("n", "<leader>de", focus_editor, d("focus editor"))
    map("n", "<leader>dv", function() focus_panel("dapui_scopes", "variables") end, d("focus variables panel"))
    map("n", "<leader>dw", function() focus_panel("dapui_watches", "expressions") end, d("focus expressions panel"))
    map("n", "<leader>db", function() focus_panel("dapui_breakpoints", "breakpoints") end, d("focus breakpoints panel"))
    map("n", "<leader>dt", function() focus_panel("dapui_console", "terminal") end, d("focus debug terminal panel"))
  end,
}
