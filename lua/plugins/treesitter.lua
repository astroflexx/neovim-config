-- treesitter.lua is a plugin for syntax parsing and highlighting

return {
  "nvim-treesitter/nvim-treesitter",
  event = "VeryLazy",
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

    -- kick treesitter for already-open buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local ft = vim.bo[buf].filetype
        if ft ~= "" then
          vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
        end
      end
    end
  end,
}
