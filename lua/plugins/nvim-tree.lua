return {
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    lazy = false,
    keys = {
      {
        "<leader>e",
        function()
          local api = require("nvim-tree.api")
          if vim.bo.filetype == "NvimTree" then
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.bo[buf].filetype ~= "NvimTree" and vim.bo[buf].buftype == "" then
                vim.api.nvim_set_current_win(win)
                return
              end
            end
          else
            api.tree.focus()
          end
        end,
      },
      { "<leader>w", "<cmd>NvimTreeClose<cr>" },
    },
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      require("nvim-tree").setup({
        view = {
          width = 37,
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
            vim.cmd.cd(data.file)
            require("nvim-tree.api").tree.open()
          elseif real_file then
            require("nvim-tree.api").tree.toggle({ focus = false, find_file = true })
          end
        end,
      })
    end,
  },
}
