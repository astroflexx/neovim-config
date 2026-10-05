-- C++ / competitive-programming buffer tweaks.

-- <leader>a: open the algo snippet picker (see lua/core/snippets.lua).
vim.keymap.set("n", "<leader>a", function()
  require("core.snippets").open()
end, { buffer = true, silent = true, desc = "insert an algo snippet" })

-- Only "/**" doc comments continue a " * " leader on Enter (like VSCode);
-- plain "/*" comments are free text. Default c 'comments' treats both alike.
vim.opt_local.comments = "s1:/**,mb:*,ex:*/,:///,://"

-- Text inside a plain /* */ block sits one indent level (shiftwidth) in from
-- the "/*", on a tab stop. cindent's default (c3) aligns it 3 columns in, just
-- past "/* ", which is off the 4-space grid when opening a line with `o`.
vim.opt_local.cinoptions:append("c1s")
