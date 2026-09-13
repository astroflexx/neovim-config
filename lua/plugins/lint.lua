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
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      callback = function()
        local filepath = vim.fn.expand("%:p")
        local home = vim.fn.expand("$HOME")
        if filepath:find(home .. "/test", 1, true) or filepath:find(home .. "/problem-solving", 1, true) then
          return
        end
        lint.try_lint()
      end,
    })
  end,
}
