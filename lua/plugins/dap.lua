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
-- the box and supports stdio redirection, which is what makes it usable for
-- competitive programming (feed a file to stdin instead of typing the test case
-- by hand - see the "stdin from input.txt" launch configuration below).
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

    ----------------------------------------------------------------------------
    -- build step (VSCode preLaunchTask equivalent)
    ----------------------------------------------------------------------------

    -- compile the current C/C++ buffer and return the path to the executable.
    -- raises on failure so nvim-dap aborts the launch; the compiler output is
    -- surfaced via vim.notify.
    local function build_current_file()
      local ft = vim.bo.filetype
      if ft ~= "cpp" and ft ~= "c" then
        error("dap: current buffer is not a C/C++ file")
      end

      vim.cmd("silent! write")

      local file = vim.fn.expand("%:p")
      local out = vim.fn.expand("%:p:h") .. "/" .. vim.fn.expand("%:t:r")
      local compiler = ft == "c" and "gcc" or "g++"
      local std = ft == "c" and "-std=c17" or "-std=c++23"

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
        vim.notify(output, vim.log.levels.ERROR, { title = "C/C++ build failed" })
        error("dap: build failed")
      end

      return out
    end

    -- stdin file for the competitive-programming launch config: input.txt sitting
    -- next to the source file.
    local function stdin_file()
      return vim.fn.expand("%:p:h") .. "/input.txt"
    end

    ----------------------------------------------------------------------------
    -- launch configurations
    --
    -- the adapter itself ("codelldb") is registered for us by mason-nvim-dap.
    ----------------------------------------------------------------------------

    -- the default launch: build the current file and debug it. this is the only
    -- entry in dap.configurations so <leader>dc never shows a picker.
    --
    -- stopOnEntry stays false: codelldb's "entry" is the process entry point
    -- (_start in the dynamic linker), not main - stopping there dumps you in
    -- disassembly. instead the <leader>dc / <leader>di helpers drop a breakpoint
    -- on main() automatically when you haven't set any, so a session always stops
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

    -- competitive-programming variant: same, but stdin is redirected from
    -- input.txt next to the source. run it directly via <leader>di.
    local launch_current_stdin = vim.tbl_extend("force", launch_current, {
      name = "C/C++: build & debug current file (stdin from input.txt)",
      stdio = { stdin_file, nil, nil },
    })

    dap.configurations.cpp = { launch_current }
    dap.configurations.c = { launch_current }

    ----------------------------------------------------------------------------
    -- UI: nvim-dap-ui + virtual text
    ----------------------------------------------------------------------------

    dapui.setup({
      -- clickable play / pause / step / restart / stop toolbar. it renders in the
      -- winbar of the element named here, so it sits at the very top of the left
      -- panel (mouse=a is on, so the buttons are clickable). true VSCode-style
      -- free-floating-over-the-editor controls aren't something dap-ui can do.
      controls = { enabled = true, element = "scopes" },
      layouts = {
        {
          -- left panel - replaces the file tree at the same width.
          -- VARIABLES on top, WATCH below, BREAKPOINTS at the bottom. no call stack.
          position = "left",
          size = 40,
          elements = {
            { id = "scopes", size = 0.5 },
            { id = "watches", size = 0.25 },
            { id = "breakpoints", size = 0.25 },
          },
        },
        {
          -- bottom panel - the program terminal: paste stdin, read stdout.
          position = "bottom",
          size = 12,
          elements = {
            { id = "console", size = 1.0 },
          },
        },
      },
    })

    require("nvim-dap-virtual-text").setup({
      commented = true, -- render the inline values as trailing comments
    })

    -- open / close the UI automatically around a session, like VSCode.
    -- while a session is running, hide nvim-tree so the dap-ui left panel takes
    -- over the space, then bring the tree back afterwards.
    local tree_was_open = false
    local function hide_tree()
      local ok, view = pcall(require, "nvim-tree.view")
      tree_was_open = ok and view.is_visible()
      if tree_was_open then
        require("nvim-tree.api").tree.close()
      end
    end
    local function restore_tree()
      if tree_was_open then
        require("nvim-tree.api").tree.open()
        tree_was_open = false
      end
    end

    dap.listeners.after.event_initialized["dapui_config"] = function()
      hide_tree()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
      restore_tree()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
      restore_tree()
    end

    ----------------------------------------------------------------------------
    -- gutter signs
    ----------------------------------------------------------------------------

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "✘", texthl = "DiagnosticWarn" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })

    ----------------------------------------------------------------------------
    -- keymaps - everything under <leader>d
    ----------------------------------------------------------------------------

    local map = vim.keymap.set
    local function d(desc)
      return { desc = "debug: " .. desc }
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
    -- flashing past.
    local function start(config)
      if dap.session() then
        dap.continue()
        return
      end
      if not has_breakpoints() then
        local win = vim.api.nvim_get_current_win()
        local cursor = vim.api.nvim_win_get_cursor(win)
        for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          if line:match("%f[%a]main%s*%(") then
            vim.api.nvim_win_set_cursor(win, { i, 0 })
            dap.toggle_breakpoint()
            vim.api.nvim_win_set_cursor(win, cursor)
            vim.notify("debug: no breakpoints set - added one at main()", vim.log.levels.WARN)
            break
          end
        end
      end
      dap.run(config)
    end

    -- session control
    map("n", "<leader>dc", function()
      start(launch_current)
    end, d("start / continue"))
    map("n", "<leader>di", function()
      start(launch_current_stdin)
    end, d("start with stdin from input.txt"))
    map("n", "<leader>dn", dap.step_over, d("step over (next)"))
    map("n", "<leader>ds", dap.step_into, d("step into"))
    map("n", "<leader>df", dap.step_out, d("step out (finish)"))
    map("n", "<leader>dh", dap.run_to_cursor, d("run to cursor (here)"))
    map("n", "<leader>dp", dap.pause, d("pause"))
    map("n", "<leader>dx", dap.terminate, d("terminate"))
    map("n", "<leader>dr", dap.restart, d("restart"))
    map("n", "<leader>dl", dap.run_last, d("run last"))

    -- breakpoints
    map("n", "<leader>db", dap.toggle_breakpoint, d("toggle breakpoint"))
    map("n", "<leader>dB", function()
      dap.set_breakpoint(vim.fn.input("breakpoint condition: "))
    end, d("conditional breakpoint"))
    map("n", "<leader>dL", function()
      dap.set_breakpoint(nil, nil, vim.fn.input("log message: "))
    end, d("logpoint"))
    map("n", "<leader>dX", dap.clear_breakpoints, d("clear all breakpoints"))
    map("n", "<leader>dq", function()
      dap.list_breakpoints()
      vim.cmd("copen")
    end, d("list breakpoints (quickfix)"))

    -- inspect / panels
    map({ "n", "v" }, "<leader>de", function()
      dapui.eval(nil, { enter = true })
    end, d("eval expression popup"))
    map({ "n", "v" }, "<leader>dw", function()
      local mode = vim.fn.mode()
      local expr
      if mode == "v" or mode == "V" then
        expr = table.concat(
          vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }),
          " "
        )
        vim.api.nvim_input("<Esc>")
      else
        expr = vim.fn.expand("<cexpr>")
      end
      dapui.elements.watches.add(expr)
    end, d("add to watches"))
    map("n", "<leader>du", dapui.toggle, d("toggle dap-ui"))
    map("n", "<leader>dR", dap.repl.toggle, d("toggle REPL"))
  end,
}
