-- treesitter.lua is a plugin for syntax parsing and highlighting

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    -- `ensure_installed` is not a real nvim-treesitter (main branch) option;
    -- the actual install API is `.install()` -- see README "Installing parsers"
    require("nvim-treesitter").install({
      "lua", "c", "cpp", "python", "javascript", "typescript",
      "html", "css", "json", "bash", "markdown", "vim", "vimdoc",
    })

	vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        vim.schedule(function()
          pcall(vim.treesitter.start, args.buf)
        end)
      end,
    })
  end,
}
