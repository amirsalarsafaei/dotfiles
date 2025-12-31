local opt = vim.opt
local g = vim.g

g.mapleader = " "
g.maplocalleader = "\\"

opt.relativenumber = true
opt.number = true

opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

opt.wrap = false

opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"

opt.backspace = "indent,eol,start"

opt.swapfile = false
opt.backup = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("state") .. "/undo"

opt.splitright = true
opt.splitbelow = true

opt.hidden = true
opt.history = 500
opt.lazyredraw = true
opt.synmaxcol = 240
opt.updatetime = 250
opt.timeoutlen = 300

opt.scrolloff = 8
opt.sidescrolloff = 8

opt.mouse = "a"

opt.clipboard = "unnamedplus"

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

opt.inccommand = "split"

opt.confirm = true

opt.fillchars = { eob = " " }

opt.shortmess:append("sI")

opt.iskeyword:append("-")
