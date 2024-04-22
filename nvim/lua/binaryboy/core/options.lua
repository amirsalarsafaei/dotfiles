local opt = vim.opt

opt.relativenumber = true
opt.number = true


-- tabs & indentation(spacing in general)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true

opt.wrap = false

-- buffer search settings
opt.ignorecase = true
opt.smartcase = true

opt.cursorline = true


-- opt.termguitcolors = true
-- opt.background = "dark"
-- opt.signcolumn = "yes"

opt.backspace = 'indent,eol,start'

-- clipboard
opt.clipboard:append("unnamedplus")
opt.swapfile = false


-- split windows
opt.splitright = true
opt.splitbelow = true
