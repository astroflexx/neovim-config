-- persistence.nvim: per-folder sessions. it saves a session keyed by cwd on
-- VimLeavePre; core/open_folder loads it (and saves the folder being left)
-- when you switch projects.

return {
  "folke/persistence.nvim",
  lazy = false,
  opts = {
    branch = false, -- one session per folder, not per git branch
    need = 0, -- still save when the folder was emptied, so it restores empty
  },
  config = function(_, opts)
    require("persistence").setup(opts)
    -- don't arm the VimLeavePre auto-save yet: a bare `nvim` sitting on the
    -- dashboard shouldn't leave a session behind. core/open_folder calls
    -- persistence.start() once an actual project is opened.
    require("persistence").stop()

    -- persistence's own exit save (and any manual save) goes through mksession,
    -- which records the window layout. drop the tree first so the session is
    -- just the editor window + its buffers.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = function()
        pcall(function()
          require("nvim-tree.api").tree.close()
        end)
      end,
    })
  end,
}
