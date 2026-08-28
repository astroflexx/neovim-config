return {
  "stevearc/conform.nvim",
  cmd = "ConformInfo",
  keys = {
    { "<leader>f", function() require("conform").format({ timeout_ms = 500, lsp_format = "fallback" }) end, desc = "Format file" },
  },
  opts = {
    formatters_by_ft = {
      cpp = { "clang-format" },
      c = { "clang-format" },
    },
  },
}
