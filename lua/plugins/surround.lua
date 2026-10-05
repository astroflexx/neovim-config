-- surround.lua: vim-surround style wrapping, like the VSCode Vim extension.
--
-- Visual mode: select text, then S followed by the delimiter.
--   S) S] S}  wrap tightly:        (text)
--   S( S[ S{  wrap with spaces:    ( text )
--   S" S' S`  wrap in quotes
-- Normal mode also gets ys{motion}{char}, cs{old}{new}, ds{char}.

return {
  "kylechui/nvim-surround",
  version = "*",
  event = "VeryLazy",
  opts = {},
}
