return {
	"sindrets/diffview.nvim",
	config = function()
		local actions = require("diffview.actions")
		local diffview = require("diffview")
		diffview.setup({
			enhanced_diff_hl = true,
			hooks = {
				diff_buf_read = function()
					vim.diagnostic.enable(false)()
				end,
			},
			keymaps = {
				disable_defaults = true,
				view = {
					{ "n", "<C-f>", actions.toggle_files,                  { desc = "Toggle the file panel" } },
					{
						"n",
						"gf",
						actions.goto_file_edit,
						{ desc = "Open the file in the previous tabpage" },
					},
					{ "n", "co",    actions.conflict_choose_all("ours"),   { desc = "Choose conflict --ours" } },
					{ "n", "ct",    actions.conflict_choose_all("theirs"), { desc = "Choose conflict --theirs" } },
					{ "n", "cb",    actions.conflict_choose_all("base"),   { desc = "Choose conflict --base" } },
					["gq"] = function()
						if vim.fn.tabpagenr("$") > 1 then
							vim.cmd.DiffviewClose()
						else
							vim.cmd.quitall()
						end
					end,
				},
				file_panel = {
					{
						"n",
						"j",
						actions.next_entry,
						{ desc = "Bring the cursor to the next file entry" },
					},
					{
						"n",
						"k",
						actions.prev_entry,
						{ desc = "Bring the cursor to the previous file entry" },
					},
					{
						"n",
						"<cr>",
						actions.select_entry,
						{ desc = "Open the diff for the selected entry" },
					},
					{ "n", "<C-f>",   actions.toggle_files,                  { desc = "Toggle the file panel" } },
					{
						"n",
						"gf",
						actions.goto_file_edit,
						{ desc = "Open the file in the previous tabpage" },
					},
					{ "n", "co",      actions.conflict_choose_all("ours"),   { desc = "Choose conflict --ours" } },
					{ "n", "ct",      actions.conflict_choose_all("theirs"), { desc = "Choose conflict --theirs" } },
					{ "n", "cb",      actions.conflict_choose_all("base"),   { desc = "Choose conflict --base" } },
					{ "n", "<Right>", actions.open_fold,                     { desc = "Expand fold" } },
					{ "n", "<Left>",  actions.close_fold,                    { desc = "Collapse fold" } },
					{ "n", "L",       actions.open_commit_log,               { desc = "Open the commit log panel" } },
					["gq"] = function()
						if vim.fn.tabpagenr("$") > 1 then
							vim.cmd.DiffviewClose()
						else
							vim.cmd.quitall()
						end
					end,
				},
				file_history_panel = {
					{
						"n",
						"j",
						actions.next_entry,
						{ desc = "Bring the cursor to the next file entry" },
					},
					{
						"n",
						"k",
						actions.prev_entry,
						{ desc = "Bring the cursor to the previous file entry" },
					},
					{
						"n",
						"<cr>",
						actions.select_entry,
						{ desc = "Open the diff for the selected entry" },
					},
					{ "n", "<C-f>",   actions.toggle_files,                  { desc = "Toggle the file panel" } },
					{
						"n",
						"gf",
						actions.goto_file_edit,
						{ desc = "Open the file in the previous tabpage" },
					},
					{ "n", "co",      actions.conflict_choose_all("ours"),   { desc = "Choose conflict --ours" } },
					{ "n", "ct",      actions.conflict_choose_all("theirs"), { desc = "Choose conflict --theirs" } },
					{ "n", "cb",      actions.conflict_choose_all("base"),   { desc = "Choose conflict --base" } },
					{ "n", "<Right>", actions.open_fold,                     { desc = "Expand fold" } },
					{ "n", "<Left>",  actions.close_fold,                    { desc = "Collapse fold" } },
					{ "n", "L",       actions.open_commit_log,               { desc = "Open the commit log panel" } },
					["gq"] = function()
						if vim.fn.tabpagenr("$") > 1 then
							vim.cmd.DiffviewClose()
						else
							vim.cmd.quitall()
						end
					end,
				},
			},
		})
	end,
}
