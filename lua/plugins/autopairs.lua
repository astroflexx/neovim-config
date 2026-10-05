-- autopairs.lua is a plugin to automatically insert bracket pairs
-- like {}, (), []

return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    local npairs = require("nvim-autopairs")
    local Rule = require("nvim-autopairs.rule")
    npairs.setup({})

    local ft = { "c", "cpp" }
    -- don't auto-close a "/*" typed inside a // line comment
    local not_in_line_comment = function(opts)
      return not opts.line:sub(1, opts.col - 1):find("//", 1, true)
    end
    local expand = function(doc)
      return function()
        return "<C-g>u<Cmd>lua require('core.block_comment').expand(" .. tostring(doc) .. ")<CR>"
      end
    end

    -- VSCode-style block comments, see lua/core/block_comment.lua.
    -- "/*" inserts " */"; typing one more "*" makes it "/** */", which the
    -- second rule (pairing disabled, Enter only) expands as a doc comment.
    npairs.add_rules({
      Rule("/*", " */", ft):with_pair(not_in_line_comment):replace_map_cr(expand(false)),
      Rule("/**", " */", ft):with_pair(function() return false end):replace_map_cr(expand(true)),
    })
  end,
}
