vim.g.mapleader = " "

-- Set default options for keymaps
local default_opts = { noremap = true, silent = true }

-- ========================================
-- GENERAL KEYMAPS
-- ========================================
vim.keymap.set("n", "<leader>c", ":nohl<CR>", { desc = "Clear search highlights", noremap = true, silent = true })
vim.keymap.set(
	"n",
	"<leader>r",
	":so %<CR>",
	{ desc = "Reload configuration without restart nvim", noremap = true, silent = true }
)
vim.keymap.set("n", "<leader>s", ":w<CR>", { desc = "Fast saving with <leader> and s", noremap = true, silent = true })

-- ========================================
-- PANE/SPLIT MANAGEMENT
-- ========================================

-- Split creation
vim.keymap.set(
	"n",
	"<leader>sv",
	"<cmd>vsplit<CR>",
	{ desc = "Split window vertically", noremap = true, silent = true }
)
vim.keymap.set(
	"n",
	"<leader>sh",
	"<cmd>split<CR>",
	{ desc = "Split window horizontally", noremap = true, silent = true }
)

-- Pane navigation (Ctrl + hjkl for seamless movement)
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left pane", noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to bottom pane", noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to top pane", noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right pane", noremap = true, silent = true })

-- Pane resizing
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size", noremap = true, silent = true })
vim.keymap.set("n", "<leader>s>", "<C-w>5>", { desc = "Increase pane width", noremap = true, silent = true })
vim.keymap.set("n", "<leader>s<", "<C-w>5<", { desc = "Decrease pane width", noremap = true, silent = true })
vim.keymap.set("n", "<leader>s+", "<C-w>5+", { desc = "Increase pane height", noremap = true, silent = true })
vim.keymap.set("n", "<leader>s-", "<C-w>5-", { desc = "Decrease pane height", noremap = true, silent = true })

-- Alternative pane resizing with arrow keys (more intuitive)
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase pane height", noremap = true, silent = true })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease pane height", noremap = true, silent = true })
vim.keymap.set(
	"n",
	"<C-Left>",
	"<cmd>vertical resize -2<CR>",
	{ desc = "Decrease pane width", noremap = true, silent = true }
)
vim.keymap.set(
	"n",
	"<C-Right>",
	"<cmd>vertical resize +2<CR>",
	{ desc = "Increase pane width", noremap = true, silent = true }
)

-- Pane management
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close active pane", noremap = true, silent = true })
vim.keymap.set("n", "<leader>so", "<C-w>o", { desc = "Close all other panes", noremap = true, silent = true })

-- Pane swapping/moving
vim.keymap.set("n", "<leader>sr", "<C-w>r", { desc = "Rotate panes", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sH", "<C-w>H", { desc = "Move pane to far left", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sJ", "<C-w>J", { desc = "Move pane to bottom", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sK", "<C-w>K", { desc = "Move pane to top", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sL", "<C-w>L", { desc = "Move pane to far right", noremap = true, silent = true })

-- ========================================
-- TAB MANAGEMENT
-- ========================================

-- Tab creation and navigation
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<CR>", { desc = "Open new tab", noremap = true, silent = true })
vim.keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab", noremap = true, silent = true })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Close all other tabs", noremap = true, silent = true })

-- Quick tab navigation (easier than leader+number)
vim.keymap.set("n", "gt", "<cmd>tabnext<CR>", { desc = "Go to next tab", noremap = true, silent = true })
vim.keymap.set("n", "gT", "<cmd>tabprev<CR>", { desc = "Go to previous tab", noremap = true, silent = true })

-- Alternative tab navigation with leader
vim.keymap.set("n", "<leader>tl", "<cmd>tabnext<CR>", { desc = "Go to next tab", noremap = true, silent = true })
vim.keymap.set("n", "<leader>th", "<cmd>tabprev<CR>", { desc = "Go to previous tab", noremap = true, silent = true })

-- Tab navigation with numbers (Alt + number for quick access)
vim.keymap.set("n", "<M-1>", "1gt", { desc = "Go to tab 1", noremap = true, silent = true })
vim.keymap.set("n", "<M-2>", "2gt", { desc = "Go to tab 2", noremap = true, silent = true })
vim.keymap.set("n", "<M-3>", "3gt", { desc = "Go to tab 3", noremap = true, silent = true })
vim.keymap.set("n", "<M-4>", "4gt", { desc = "Go to tab 4", noremap = true, silent = true })
vim.keymap.set("n", "<M-5>", "5gt", { desc = "Go to tab 5", noremap = true, silent = true })
vim.keymap.set("n", "<M-6>", "6gt", { desc = "Go to tab 6", noremap = true, silent = true })
vim.keymap.set("n", "<M-7>", "7gt", { desc = "Go to tab 7", noremap = true, silent = true })
vim.keymap.set("n", "<M-8>", "8gt", { desc = "Go to tab 8", noremap = true, silent = true })
vim.keymap.set("n", "<M-9>", "9gt", { desc = "Go to tab 9", noremap = true, silent = true })

-- Tab movement
vim.keymap.set(
	"n",
	"<leader>tm>",
	"<cmd>tabmove +1<CR>",
	{ desc = "Move tab to the right", noremap = true, silent = true }
)
vim.keymap.set(
	"n",
	"<leader>tm<",
	"<cmd>tabmove -1<CR>",
	{ desc = "Move tab to the left", noremap = true, silent = true }
)

-- Quick tab creation shortcuts
vim.keymap.set("n", "<M-t>", "<cmd>tabnew<CR>", { desc = "Open new tab (Alt+t)", noremap = true, silent = true })
vim.keymap.set("n", "<M-w>", "<cmd>tabclose<CR>", { desc = "Close current tab (Alt+w)", noremap = true, silent = true })

-- Clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y')
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p')
vim.keymap.set("n", "<leader>Y", '"+Y')
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P')
