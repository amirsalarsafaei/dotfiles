return {
	"sindrets/diffview.nvim",
	event = "VeryLazy",
	config = function()
		local actions = require("diffview.actions")
		local diffview = require("diffview")

		diffview.setup({
			enhanced_diff_hl = true,
			hooks = {
				diff_buf_read = function(bufnr)
					-- Disable diagnostics specifically for the diff buffer
					if vim.diagnostic.enable then
						vim.diagnostic.enable(false, { bufnr = bufnr })
					elseif vim.diagnostic.disable then
						vim.diagnostic.disable(bufnr)
					end
				end,
			},
			keymaps = {
				disable_defaults = true,
				-- VIEW: The actual 2-panel or 3-panel diff split
				view = {
					-- Navigation
					{ "n", "<C-f>", actions.toggle_files,            { desc = "Toggle the file panel" } },
					{ "n", "gf",    actions.goto_file_edit,          { desc = "Open the file in the previous tabpage" } },

					-- CONFLICTS: Under Cursor (Lowercase)
					{ "n", "co",    actions.conflict_choose("ours"), { desc = "Choose conflict --ours (Under Cursor)" } },
					{
						"n",
						"ct",
						actions.conflict_choose("theirs"),
						{ desc = "Choose conflict --theirs (Under Cursor)" },
					},
					{ "n", "cb", actions.conflict_choose("base"), { desc = "Choose conflict --base (Under Cursor)" } },

					-- CONFLICTS: Whole File (Uppercase / Shift)
					{
						"n",
						"cO",
						actions.conflict_choose_all("ours"),
						{ desc = "Choose conflict --ours (Whole File)" },
					},
					{
						"n",
						"cT",
						actions.conflict_choose_all("theirs"),
						{ desc = "Choose conflict --theirs (Whole File)" },
					},
					{
						"n",
						"cB",
						actions.conflict_choose_all("base"),
						{ desc = "Choose conflict --base (Whole File)" },
					},

					-- Exiting
					{
						"n",
						"gq",
						function()
							if vim.fn.tabpagenr("$") > 1 then
								vim.cmd.DiffviewClose()
							else
								vim.cmd.quitall()
							end
						end,
						{ desc = "Close diffview" },
					},
				},

				-- FILE PANEL: The list/tree of files on the left/right
				file_panel = {
					{ "n", "j",     actions.next_entry,     { desc = "Bring the cursor to the next file entry" } },
					{ "n", "k",     actions.prev_entry,     { desc = "Bring the cursor to the previous file entry" } },
					{ "n", "<cr>",  actions.select_entry,   { desc = "Open the diff for the selected entry" } },
					{ "n", "<C-f>", actions.toggle_files,   { desc = "Toggle the file panel" } },
					{ "n", "gf",    actions.goto_file_edit, { desc = "Open the file in the previous tabpage" } },

					-- CONFLICTS: File Panel only supports "Whole File" actions
					{
						"n",
						"cO",
						actions.conflict_choose_all("ours"),
						{ desc = "Choose conflict --ours (Whole File)" },
					},
					{
						"n",
						"cT",
						actions.conflict_choose_all("theirs"),
						{ desc = "Choose conflict --theirs (Whole File)" },
					},
					{
						"n",
						"cB",
						actions.conflict_choose_all("base"),
						{ desc = "Choose conflict --base (Whole File)" },
					},

					{ "n", "<Right>", actions.open_fold,       { desc = "Expand fold" } },
					{ "n", "<Left>",  actions.close_fold,      { desc = "Collapse fold" } },
					{ "n", "L",       actions.open_commit_log, { desc = "Open the commit log panel" } },
					{
						"n",
						"gq",
						function()
							if vim.fn.tabpagenr("$") > 1 then
								vim.cmd.DiffviewClose()
							else
								vim.cmd.quitall()
							end
						end,
						{ desc = "Close diffview" },
					},
				},

				-- HISTORY: The git log view
				file_history_panel = {
					{ "n", "j",       actions.next_entry,      { desc = "Bring the cursor to the next file entry" } },
					{ "n", "k",       actions.prev_entry,      { desc = "Bring the cursor to the previous file entry" } },
					{ "n", "<cr>",    actions.select_entry,    { desc = "Open the diff for the selected entry" } },
					{ "n", "<C-f>",   actions.toggle_files,    { desc = "Toggle the file panel" } },
					{ "n", "gf",      actions.goto_file_edit,  { desc = "Open the file in the previous tabpage" } },
					{ "n", "<Right>", actions.open_fold,       { desc = "Expand fold" } },
					{ "n", "<Left>",  actions.close_fold,      { desc = "Collapse fold" } },
					{ "n", "L",       actions.open_commit_log, { desc = "Open the commit log panel" } },
					{
						"n",
						"gq",
						function()
							if vim.fn.tabpagenr("$") > 1 then
								vim.cmd.DiffviewClose()
							else
								vim.cmd.quitall()
							end
						end,
						{ desc = "Close diffview" },
					},
				},
			},
		})
	end,
}
