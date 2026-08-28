return {
  "mfussenegger/nvim-lint",
  ft = { "cpp", "c" },
  config = function()
    local lint = require("lint")
    lint.linters_by_ft = {
      cpp = { "cpplint" },
      c = { "cpplint" },
    }
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      callback = function()
        local filepath = vim.fn.expand("%:p")
        if filepath:find(vim.fn.expand("$HOME") .. "/test", 1, true) then
          return
        end
        lint.try_lint()
      end,
    })
  end,
}
