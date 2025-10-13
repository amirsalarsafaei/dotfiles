return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")
			local builtin = require("telescope.builtin")

			-- ============================================================================
			-- CUSTOM ACTIONS
			-- ============================================================================

			-- Live change glob pattern
			local function change_glob_pattern(prompt_bufnr)
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local current_input = action_state.get_current_line()

				vim.ui.input({
					prompt = "Glob pattern: ",
					default = current_picker.finder.glob_pattern or "",
				}, function(pattern)
					if pattern then
						actions.close(prompt_bufnr)
						builtin.live_grep({
							default_text = current_input,
							glob_pattern = pattern,
						})
					end
				end)
			end

			-- Live change search directory
			local function change_directory(prompt_bufnr)
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local current_input = action_state.get_current_line()

				vim.ui.input({
					prompt = "Directory: ",
					default = "./",
					completion = "dir",
				}, function(dir)
					if dir then
						actions.close(prompt_bufnr)
						builtin.live_grep({
							default_text = current_input,
							search_dirs = { dir },
						})
					end
				end)
			end

			-- ============================================================================
			-- SETUP
			-- ============================================================================
			telescope.setup({
				defaults = {
					path_display = { "smart" },
					mappings = {
						i = {
							-- Navigation
							["<M-k>"] = actions.move_selection_previous,
							["<M-j>"] = actions.move_selection_next,

							-- Selection
							["<Tab>"] = actions.toggle_selection + actions.move_selection_next,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_previous,
							["<C-a>"] = actions.select_all,

							-- Quick actions
							["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
							["<C-x>"] = actions.delete_buffer,

							-- History
							["<C-n>"] = actions.cycle_history_next,
							["<C-p>"] = actions.cycle_history_prev,

							-- Live filters (THE KEY MAPPINGS)
							["<C-g>"] = change_glob_pattern,
							["<C-d>"] = change_directory,
							["<C-f>"] = actions.to_fuzzy_refine,
						},
						n = {
							["<Tab>"] = actions.toggle_selection + actions.move_selection_next,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_previous,
							["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
							["dd"] = actions.delete_buffer,
						},
					},
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--hidden",
						"--glob",
						"!**/.git/*",
					},
				},
				pickers = {
					find_files = {
						find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
					},
					live_grep = {
						additional_args = function()
							return { "--hidden", "--glob", "!**/.git/*" }
						end,
					},
				},
			})

			telescope.load_extension("fzf")

			-- ============================================================================
			-- HELPER FUNCTIONS
			-- ============================================================================

			-- Prompt for glob pattern before starting
			local function grep_with_glob()
				vim.ui.input({
					prompt = "Glob pattern: ",
				}, function(pattern)
					if pattern then
						builtin.live_grep({ glob_pattern = pattern })
					end
				end)
			end

			-- Prompt for directory before starting
			local function grep_in_directory()
				vim.ui.input({
					prompt = "Directory: ",
					default = "./",
					completion = "dir",
				}, function(dir)
					if dir then
						builtin.live_grep({ search_dirs = { dir } })
					end
				end)
			end

			-- ============================================================================
			-- KEYMAPS
			-- ============================================================================

			local keymap = vim.keymap.set

			-- Files
			keymap("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
			keymap("n", "<leader>fa", function()
				builtin.find_files({ no_ignore = true, hidden = true })
			end, { desc = "Find all files" })
			keymap("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
			keymap("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })

			-- Search
			keymap("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
			keymap("n", "<leader>fw", builtin.grep_string, { desc = "Grep word under cursor" })
			keymap("n", "<leader>f/", grep_with_glob, { desc = "Grep with file filter" })
			keymap("n", "<leader>fd", grep_in_directory, { desc = "Grep in directory" })

			-- Git
			keymap("n", "<leader>gc", builtin.git_commits, { desc = "Git commits" })
			keymap("n", "<leader>gs", builtin.git_status, { desc = "Git status" })
			keymap("n", "<leader>gb", builtin.git_branches, { desc = "Git branches" })

			-- Vim
			keymap("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
			keymap("n", "<leader>fk", builtin.keymaps, { desc = "Keymaps" })
			keymap("n", "<leader>fc", builtin.commands, { desc = "Commands" })

			-- Lists
			keymap("n", "<leader>fq", builtin.quickfix, { desc = "Quickfix" })
			keymap("n", "<leader>fm", builtin.marks, { desc = "Marks" })
			keymap("n", '<leader>f"', builtin.registers, { desc = "Registers" })

			-- Resume
			keymap("n", "<leader>f.", builtin.resume, { desc = "Resume picker" })
		end,
	},
}
