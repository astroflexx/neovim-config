-- options.lua is a settings file, to set some global options

local opt = vim.opt

-- direct port from my .vimrc
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.number = true

-- neovim essentials
opt.smartindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.splitbelow = true
opt.splitright = true
-- Keep the *cursor* put when a split (the terminal panel) opens/closes below.
--
-- "screen" pins the topline instead, which looks right only while the cursor
-- happens to sit in the rows the shrunken window keeps. Anywhere lower and
-- neovim clamps the cursor up into the new viewport (line 26 -> 13 with the
-- panel at 45%), and closing the panel does not put it back - the position is
-- simply gone. "cursor" never moves the cursor: it leaves the viewport alone
-- while the cursor still fits, scrolls the minimum needed when it doesn't, and
-- scrolls back when the panel closes.
opt.splitkeep = "cursor"
-- per-folder sessions (persistence.nvim): persist the buffer list + cwd only.
-- the window layout is always [tree | editor] and is rebuilt by
-- core/open_folder, so saving it would only fight the restore.
opt.sessionoptions = "buffers,curdir,folds"
-- Don't sync all yanks/deletes with system clipboard; use "+y / "+p explicitly
opt.undofile = true
opt.updatetime = 250
opt.mouse = "a"
opt.timeoutlen = 400
opt.showmode = false
opt.laststatus = 3

-- cursor shape per mode; the trailing "a:" entry gives *every* mode - terminal
-- and command-line included - the same color and blink.
--
-- naming Cursor for all modes matters: any mode left out of 'guicursor' keeps
-- neovim's default entry, and the defaults for t/c/sm carry either no highlight
-- group or TermCursor (reverse video, no colors of its own). The TUI reads both
-- as "use the host terminal's cursor color" and emits OSC 112, so alacritty's
-- [colors.cursor] #ffffff took over - a glaring white block in terminal mode.
opt.guicursor = table.concat({
  "n-v-o-t:block",
  "i-ci-ve:ver25",
  "r-cr:hor20",
  "a:Cursor-blinkwait1-blinkon1-blinkoff1",
}, ",")
-- the Cursor highlight itself is defined in plugins/theme.lua: the colorscheme
-- runs `hi clear` when it loads, which would wipe anything set here.
