return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
    keys = {
      {
        "<leader>w",
        function()
          require("nvim-tree.api").tree.focus()
        end,
        desc = "Focus / open the file tree",
      },
      {
        "<leader>r",
        function()
          require("nvim-tree.api").tree.change_root(vim.g.nvim_tree_original_cwd)
        end,
        desc = "Reset nvim-tree to original root",
      },
    },
    config = function()
      vim.g.nvim_tree_original_cwd = vim.fn.getcwd()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.g.nvim_tree_view_width = 37
      require("nvim-tree").setup({
        -- `nvim <dir>` is handled by core/open_folder via the VimEnter hook
        -- below (session restore + tree + empty state). nvim-tree must not
        -- grab the directory buffer on startup and pre-empt it - otherwise
        -- the hook sees nvim-tree's own buffer, not the dir path, and the
        -- session is never restored.
        hijack_directories = { enable = false },
        view = {
          width = vim.g.nvim_tree_view_width,
        },
        filters = {
          dotfiles = true,
        },
      })

      local original_guicursor = vim.o.guicursor
      vim.api.nvim_set_hl(0, "NvimTreeHiddenCursor", { blend = 100, nocombine = true })

      local function apply_cursor()
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(0) then return end
          if vim.bo.filetype == "NvimTree" then
            vim.o.guicursor = "a:NvimTreeHiddenCursor"
          else
            vim.o.guicursor = original_guicursor
          end
        end)
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        callback = apply_cursor,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function(data)
          local directory = vim.fn.isdirectory(data.file) == 1
          local real_file = vim.fn.filereadable(data.file) == 1
          if directory then
            -- `nvim <dir>`: open it as the project root, restoring its
            -- saved session if there is one (see core/open_folder).
            require("core.open_folder").open(data.file)
          elseif real_file then
            require("core.open_folder").current = vim.fn.getcwd()
            require("nvim-tree.api").tree.toggle({ focus = false, find_file = true })
          end
        end,
      })
    end,
  },
}
