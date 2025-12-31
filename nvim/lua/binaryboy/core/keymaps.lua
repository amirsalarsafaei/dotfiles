local map = vim.keymap.set

map("n", "<leader>c", "<cmd>nohl<CR>", { desc = "Clear search highlights" })
map("n", "<leader>r", "<cmd>so %<CR>", { desc = "Reload current file" })
map("n", "<leader>s", "<cmd>w<CR>", { desc = "Save file" })

map("n", "<Esc>", "<cmd>nohl<CR><Esc>", { desc = "Clear highlights on escape" })

map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = "Move down (wrapped)" })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = "Move up (wrapped)" })

map("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>sh", "<cmd>split<CR>", { desc = "Split horizontal" })
map("n", "<leader>se", "<C-w>=", { desc = "Equalize splits" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close split" })
map("n", "<leader>so", "<C-w>o", { desc = "Close other splits" })

map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase width" })

map("n", "<leader>sr", "<C-w>r", { desc = "Rotate splits" })
map("n", "<leader>sH", "<C-w>H", { desc = "Move split left" })
map("n", "<leader>sJ", "<C-w>J", { desc = "Move split down" })
map("n", "<leader>sK", "<C-w>K", { desc = "Move split up" })
map("n", "<leader>sL", "<C-w>L", { desc = "Move split right" })

map("n", "<leader>tn", "<cmd>tabnew<CR>", { desc = "New tab" })
map("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close tab" })
map("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Close other tabs" })
map("n", "<leader>tl", "<cmd>tabnext<CR>", { desc = "Next tab" })
map("n", "<leader>th", "<cmd>tabprev<CR>", { desc = "Previous tab" })

for i = 1, 9 do
	map("n", "<M-" .. i .. ">", i .. "gt", { desc = "Go to tab " .. i })
end
map("n", "<M-t>", "<cmd>tabnew<CR>", { desc = "New tab" })
map("n", "<M-w>", "<cmd>tabclose<CR>", { desc = "Close tab" })

map("v", "<", "<gv", { desc = "Indent left and reselect" })
map("v", ">", ">gv", { desc = "Indent right and reselect" })

map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

map("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next search (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search (centered)" })

map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

map("n", "[q", "<cmd>cprev<CR>zz", { desc = "Previous quickfix" })
map("n", "]q", "<cmd>cnext<CR>zz", { desc = "Next quickfix" })
map("n", "[l", "<cmd>lprev<CR>zz", { desc = "Previous loclist" })
map("n", "]l", "<cmd>lnext<CR>zz", { desc = "Next loclist" })

map("n", "Q", "@q", { desc = "Replay macro q" })

map("i", "<C-c>", "<Esc>", { desc = "Exit insert mode" })
