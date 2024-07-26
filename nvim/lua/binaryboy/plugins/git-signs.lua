return {
	"lewis6991/gitsigns.nvim",
	config = function()
		local gitsigns = require("gitsigns")
		gitsigns.setup({
			signs = {
				add = { text = "┃" },
				change = { text = "┃" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
				untracked = { text = "┆" },
			},
			signs_staged = {
				add = { text = "┃" },
				change = { text = "┃" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
				untracked = { text = "┆" },
			},
			signs_staged_enable = true,
			signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
			numhl = false,  -- Toggle with `:Gitsigns toggle_numhl`
			linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
			word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
			watch_gitdir = {
				follow_files = true,
			},
			auto_attach = true,
			attach_to_untracked = true,
			current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
				delay = 1000,
				ignore_whitespace = false,
				virt_text_priority = 100,
			},
			current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
			sign_priority = 6,
			update_debounce = 100,
			status_formatter = nil, -- Use default
			max_file_length = 40000, -- Disable if file is longer than this (in lines)
			preview_config = {
				-- Options passed to nvim_open_win
				border = "single",
				style = "minimal",
				relative = "cursor",
				row = 0,
				col = 1,
			},
			on_attach = function(bufnr)
				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					Map(mode, l, r, opts)
				end

				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gitsigns.nav_hunk("next")
					end
				end, { desc = "next hunk" })

				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gitsigns.nav_hunk("prev")
					end
				end, { desc = "previous hunk" })

				-- Actions
				map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "stages diff hunk" })
				map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "resets diff hunk" })
				map("v", "<leader>hs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "stages diff hunk" })
				map("v", "<leader>hr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "resets diff hunk" })
				map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "stage all buffer diff hunks" })
				map("n", "<leader>hu", gitsigns.undo_stage_hunk, { desc = "undo staged hunk" })
				map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "reset all buffer diff hunks" })
				map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "preview this diff hunk" })
				map("n", "<leader>hb", function()
					gitsigns.blame_line({ full = true })
				end, { desc = "GitBlame this line" })
				map("n", "<leader>htb", gitsigns.toggle_current_line_blame, { desc = "Toggles GitBlame for line" })
				map("n", "<leader>hd", gitsigns.diffthis, { desc = "Vim diff against index" })
				map("n", "<leader>hD", function()
					gitsigns.diffthis("~")
				end)
				map("n", "<leader>htd", gitsigns.toggle_deleted, { desc = "shows old deleted version in virtual line" })

				-- Text object
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
			end,
		})
	end,
}
