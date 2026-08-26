-- treesitter.lua is a plugin for syntax parsing and highlighting

return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({
      "c", "cpp", "rust", "go", "java", "python",
      "lua", "json", "html", "css", "bash", "markdown", "vim", "vimdoc",
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = {
        "c", "cpp", "rust", "go", "java", "python",
        "lua", "json", "html", "css", "bash", "markdown", "vim", "vimdoc",
      },
      callback = function(args)
        vim.treesitter.start(args.buf)
      end,
    })
  end,
}
