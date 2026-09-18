return {
  "mfussenegger/nvim-lint",
  ft = { "cpp", "c", "go" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      cpp = { "cpplint" },
      c = { "cpplint" },
      go = { "golangcilint" },
    }
    lint.linters.golangcilint.ignore_exitcode = true
    local lint_exclude = require("core.lint_exclude")
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      callback = function(args)
        if lint_exclude.is_excluded(args.buf) then
          return
        end
        lint.try_lint()
      end,
    })
  end,
}
