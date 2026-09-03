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
-- keep the text visually put when a split (the terminal panel) opens/closes
-- below - only the window resizes, the viewport doesn't jump
opt.splitkeep = "screen"
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
