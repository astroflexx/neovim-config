-- dap.lua sets up debugging, the neovim equivalent of VSCode's "Run and Debug".
--
-- stack:
--   nvim-dap            - the debug engine / DAP client
--   nvim-dap-ui         - the VSCode-style panels (scopes, breakpoints, stacks, repl)
--   nvim-dap-virtual-text - inline variable values next to the code, like VSCode
--   mason-nvim-dap      - installs the actual debug adapter (codelldb) via mason
--
-- codelldb is the adapter used for C, C++ and Rust. it's the same LLDB-based
-- backend the CodeLLDB VSCode extension uses, and it supports stdio redirection,
-- which is what makes it usable for competitive programming (feed a file to
-- stdin instead of typing the test case by hand - see the "cpp (stdin file)"
-- launch configuration below).

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

    dapui.setup()
    require("nvim-dap-virtual-text").setup({})

    -- adapter: mason-nvim-dap registers `codelldb` for us, so we only need the
    -- launch configurations. define them for both cpp and c.
    local cpp = {
      {
        name = "cpp: launch",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      },
      {
        -- competitive-programming variant: reads stdin from a file in the cwd.
        -- change the filename here or make a copy if you use something else.
        name = "cpp: launch (stdin from input.txt)",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        stdio = { "${workspaceFolder}/input.txt", nil, nil },
      },
    }
    dap.configurations.cpp = cpp
    dap.configurations.c = cpp

    -- open / close the UI automatically around a session, like VSCode.
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- signs in the gutter
    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })

    -- keymaps - the F-keys match VSCode.
    local map = vim.keymap.set
    map("n", "<F5>", dap.continue, { desc = "debug: start/continue" })
    map("n", "<F10>", dap.step_over, { desc = "debug: step over" })
    map("n", "<F11>", dap.step_into, { desc = "debug: step into" })
    map("n", "<F12>", dap.step_out, { desc = "debug: step out" })
    map("n", "<leader>db", dap.toggle_breakpoint, { desc = "debug: toggle breakpoint" })
    map("n", "<leader>dB", function()
      dap.set_breakpoint(vim.fn.input("breakpoint condition: "))
    end, { desc = "debug: conditional breakpoint" })
    map("n", "<leader>dr", dap.repl.toggle, { desc = "debug: toggle repl" })
    map("n", "<leader>dl", dap.run_last, { desc = "debug: run last" })
    map("n", "<leader>dt", dap.terminate, { desc = "debug: terminate" })
    map("n", "<leader>du", dapui.toggle, { desc = "debug: toggle ui" })
  end,
}
