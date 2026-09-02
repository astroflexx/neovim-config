-- C++ / competitive-programming buffer tweaks.

-- <leader>a: open the algo snippet picker (see lua/core/snippets.lua).
vim.keymap.set("n", "<leader>a", function()
  require("core.snippets").open()
end, { buffer = true, silent = true, desc = "insert an algo snippet" })
