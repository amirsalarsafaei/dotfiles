return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			-- We just list the dependency, but we DON'T build it here on NixOS
			{ "nvim-telescope/telescope-fzf-native.nvim" },
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")
			local builtin = require("telescope.builtin")

			-- ============================================================================
			-- SETUP
			-- ============================================================================
			telescope.setup({
				defaults = {
					prompt_prefix = "   ",
					selection_caret = "  ",
					entry_prefix = "  ",
					initial_mode = "insert",
					selection_strategy = "reset",
					sorting_strategy = "ascending",
					layout_strategy = "horizontal",
					layout_config = {
						horizontal = {
							prompt_position = "top",
							preview_width = 0.55,
							results_width = 0.8,
						},
						width = 0.87,
						height = 0.80,
						preview_cutoff = 120,
					},
					path_display = { "truncate" },
					-- Mappings
					mappings = {
						i = {
							["<C-k>"] = actions.move_selection_previous,
							["<C-j>"] = actions.move_selection_next,
							["<C-u>"] = actions.preview_scrolling_up,
							["<C-d>"] = actions.preview_scrolling_down,
							["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
							["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						},
						n = {
							["q"] = actions.close,
							["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
							["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
						},
					},
				},
				pickers = {
					find_files = {
						find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
					},
					buffers = {
						ignore_current_buffer = true,
						sort_mru = true,
						mappings = {
							i = { ["<C-x>"] = actions.delete_buffer },
							n = { ["dd"] = actions.delete_buffer },
						},
					},
				},
				extensions = {
					-- FZF configuration (optional, only active if loaded)
					fzf = {
						fuzzy = true,
						override_generic_sorter = true,
						override_file_sorter = true,
						case_mode = "smart_case",
					},
				},
			})

			-- ============================================================================
			-- SAFELY LOAD EXTENSIONS
			-- ============================================================================
			-- This prevents a crash if fzf-native is not installed via Nix
			pcall(telescope.load_extension, "fzf")

			-- ============================================================================
			-- CUSTOM FUNCTIONS & KEYMAPS
			-- ============================================================================
			local function smart_find_files()
				local is_git = vim.fn.system("git rev-parse --is-inside-work-tree"):match("true")
				if is_git then
					builtin.git_files({ show_untracked = true })
				else
					builtin.find_files({ hidden = true })
				end
			end

			local keymap = vim.keymap.set

			-- Files
			keymap("n", "<leader>ff", smart_find_files, { desc = "Find files (smart)" })
			keymap("n", "<leader>fa", function()
				builtin.find_files({ no_ignore = true, hidden = true })
			end, { desc = "Find all files" })
			keymap("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
			keymap("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })

			-- Search
			keymap("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
			keymap("n", "<leader>fw", builtin.grep_string, { desc = "Grep word under cursor" })
			keymap("n", "<leader>sb", builtin.current_buffer_fuzzy_find, { desc = "Search current buffer" })

			-- Lists
			keymap("n", "<leader>fq", builtin.quickfix, { desc = "Quickfix" })
			keymap("n", "<leader>f.", builtin.resume, { desc = "Resume last picker" })
		end,
	},
}
