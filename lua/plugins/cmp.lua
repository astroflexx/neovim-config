return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "onsails/lspkind.nvim",
  },
  config = function()
    local cmp = require("cmp")
    local lspkind = require("lspkind")

    vim.api.nvim_set_hl(0, "CmpNormal", { bg = "#252526", fg = "#d4d4d4" })
    vim.api.nvim_set_hl(0, "CmpSelection", { bg = "#094771", fg = "#ffffff" })
    vim.api.nvim_set_hl(0, "CmpBorder", { fg = "#454545", bg = "#252526" })

    local function fixed_width(s, width)
      if #s > width then
        s = s:sub(1, width - 3) .. "..."
      end
      return s .. string.rep(" ", width - #s)
    end

    cmp.setup({
      performance = {
        max_view_entries = 10,
      },
      snippet = {
        expand = function(args)
          vim.snippet.expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<Tab>"] = cmp.mapping.select_next_item(),
        ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<C-e>"] = cmp.mapping.abort(),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
      }, {
        { name = "buffer" },
        { name = "path" },
      }),
      completion = {
        completeopt = "menu,menuone,noinsert",
      },
      view = {
        docs = {
          auto_open = false,
        },
      },
      window = {
        completion = {
          border = "none",
          winhighlight = "Normal:CmpNormal,CursorLine:CmpSelection,FloatBorder:CmpBorder,Search:None",
          scrollbar = true,
          side_padding = 0,
          col_offset = 2,
        },
      },
      formatting = {
        fields = { "kind", "abbr" },
        format = function(entry, vim_item)
          local kind_text = vim_item.kind
          vim_item.kind = " " .. (lspkind.symbol_map[vim_item.kind] or "")

          local detail = entry.completion_item.detail
          if detail and detail ~= "" then
            detail = detail:gsub("%s+", " "):gsub("^%s+", "")
          else
            detail = kind_text
          end

          local name = vim_item.abbr
          local total = 38
          local max_name = 18
          local max_detail = 18

          if #name > max_name then
            name = name:sub(1, max_name - 3) .. "..."
          end
          if #detail > max_detail then
            detail = detail:sub(1, max_detail - 3) .. "..."
          end

          local gap = total - #name - #detail
          if gap < 2 then gap = 2 end
          vim_item.abbr = name .. string.rep(" ", gap) .. detail

          return vim_item
        end,
      },
    })

    -- nvim-cmp's custom_entries_view always reserves one extra column on the
    -- right edge of the menu (see the trailing `+ 1` in `open()` and the
    -- `1 + column_width - width` padding after *every* field in `draw()` in
    -- lua/cmp/view/custom_entries_view.lua). There is no config option for it
    -- (`window.completion.side_padding` only ever adds more), so shrink the
    -- menu window by one column after it opens to drop that trailing gap.
    local ok, cev = pcall(require, "cmp.view.custom_entries_view")
    if ok and not cev._trim_trailing_col_patched then
      cev._trim_trailing_col_patched = true
      local orig_open = cev.open
      cev.open = function(self, offset, entries)
        orig_open(self, offset, entries)
        local w = self.entries_win
        if w and w.win and vim.api.nvim_win_is_valid(w.win) and (w.style.width or 0) > 1 then
          w.style.width = w.style.width - 1
          w:open()
        end
      end
    end
  end,
}
