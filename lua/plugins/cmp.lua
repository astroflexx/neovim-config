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
    local compare = require("cmp.config.compare")
    local lspkind = require("lspkind")
    local KIND = require("cmp.types").lsp.CompletionItemKind

    -- Keep the LSP menu predictable: for a given prefix it should always show
    -- the same rows. clangd (with <bits/stdc++.h> in scope) also offers
    --   * Constructor entries  -> "vector  [12 overloads]"
    --   * libstdc++ internals  -> "_Vector_base", "__normal_iterator", ...
    -- which duplicate / clutter the real `vector` Class entry. Drop both.
    local function lsp_entry_filter(entry)
      local item = entry.completion_item
      local label = (item.label or ""):gsub("^%s+", "")
      if item.kind == KIND.Constructor then
        return false
      end
      if label:match("^__") or label:match("^_%u") then
        return false
      end
      return true
    end

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
        -- <Tab> is shared three ways, in priority order: move down the
        -- completion menu if it's open, else jump to the next $1.. $0 tabstop
        -- of an active snippet (inserted from the <leader>a picker, see
        -- lua/core/snippets.lua), else a literal tab. `s` mode matters: after
        -- expansion you land in select mode on a placeholder.
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif vim.snippet.active({ direction = 1 }) then
            vim.snippet.jump(1)
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif vim.snippet.active({ direction = -1 }) then
            vim.snippet.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<C-e>"] = cmp.mapping.abort(),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp", entry_filter = lsp_entry_filter },
      }, {
        { name = "buffer" },
        { name = "path" },
      }),
      -- Deterministic ordering: the menu for a given prefix looks the same
      -- every time. nvim-cmp's default `comparators` include `recently_used`
      -- and `locality`, which reorder entries based on what you picked before
      -- / what's near the cursor -- that's why `pmr::vector` floats to the top
      -- after one use. Drop both; rank purely on the match itself.
      sorting = {
        priority_weight = 2,
        comparators = {
          compare.offset,
          compare.exact,
          compare.score,
          compare.kind,
          compare.sort_text,
          compare.length,
          compare.order,
        },
      },
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
          -- clangd delivers language constructs like `decltype~`, `static_cast~`,
          -- `dynamic_cast~` as CompletionItemKind.Snippet (they end in `~`). With
          -- snippetSupport=false they insert as plain text -- effectively keywords
          -- -- so relabel them "Keyword" in the menu instead of "Snippet".
          if vim_item.kind == "Snippet" then
            vim_item.kind = "Keyword"
          end

          local kind_text = vim_item.kind
          vim_item.kind = " " .. (lspkind.symbol_map[vim_item.kind] or "")

          local detail = entry.completion_item.detail
          if detail and detail ~= "" then
            detail = detail:gsub("%s+", " "):gsub("^%s+", "")
          else
            detail = kind_text
          end

          -- clangd suffixes its keyword-pattern entries with `~` (decltype~,
          -- static_cast~, ...). Drop it from the displayed label.
          local name = (vim_item.abbr or ""):gsub("~$", "")
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

    -- nvim-cmp only re-queries completion when the cursor moves exactly one
    -- column forward (the `lp[2] + 1 == pos[2]` guard in its TextChangedI
    -- handler, nvim-cmp/lua/cmp/init.lua). So deleting text never refreshes the
    -- menu: backspacing from "cin" back to "c" keeps the stale "cin" list, and
    -- clearing the keyword leaves the menu open. Re-run completion ourselves on
    -- any insert-mode deletion, and dismiss the menu once no keyword remains.
    local last_line = {}
    vim.api.nvim_create_autocmd({ "InsertEnter", "TextChangedI", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("cmp_refresh_on_delete", { clear = true }),
      callback = function(args)
        if args.event == "InsertLeave" then
          last_line[args.buf] = nil
          return
        end

        local line = vim.api.nvim_get_current_line()
        local prev = last_line[args.buf]
        last_line[args.buf] = line

        if args.event == "InsertEnter" or not prev or #line >= #prev then
          return -- typing forward / no deletion; nvim-cmp handles it
        end

        local col = vim.fn.col(".") - 1
        local char = col > 0 and line:sub(col, col) or ""
        if char:match("[%w_]") then
          -- Manual reason forces a fresh source request (Auto is a no-op here
          -- when the source already returned a complete list for the longer
          -- prefix, e.g. clangd for "null" -> stale on backspace to "nul").
          cmp.complete({ reason = cmp.ContextReason.Manual })
        elseif cmp.visible() then
          cmp.close()
        end
      end,
    })
  end,
}
