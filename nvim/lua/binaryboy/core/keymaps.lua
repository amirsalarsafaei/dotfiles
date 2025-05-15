vim.g.mapleader = " "

-- Set default options for keymaps
local default_opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>c", ":nohl<CR>", { desc = "Clears search highlights", noremap = true, silent = true })

vim.keymap.set("n", "<leader>r", ":so %<CR>", { desc = "Reload configuration without restart nvim", noremap = true, silent = true })

vim.keymap.set("n", "<leader>s", ":w<CR>", { desc = "Fast saving with <leader> and s", noremap = true, silent = true })

vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split window vertically", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sh", "<C-w>sh", { desc = "Split window horizontally", noremap = true, silent = true })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size", noremap = true, silent = true })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Closes active pane", noremap = true, silent = true })

