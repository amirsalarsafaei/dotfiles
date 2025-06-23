return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			"nvim-tree/nvim-web-devicons",
			"folke/todo-comments.nvim",
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")
			local transform_mod = require("telescope.actions.mt").transform_mod

			local trouble = require("trouble")
			local trouble_telescope = require("trouble.sources.telescope")


			local custom_actions = transform_mod({
				open_trouble_qflist = function(prompt_bufnr)
					trouble.toggle("quickfix")
				end,
			})

			telescope.setup({
				defaults = {
					path_display = { "smart" },
					mappings = {
						i = {
							-- Navigation
							["<C-k>"] = actions.move_selection_previous,
							["<C-j>"] = actions.move_selection_next,

							-- Multi-select operations
							["<Tab>"] = actions.toggle_selection + actions.move_selection_next,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_previous,
							["<C-a>"] = actions.select_all,
							["<C-r>"] = actions.drop_all,

							-- Send to quickfix/location list
							["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
							["<C-l>"] = actions.send_selected_to_loclist + actions.open_loclist,

							-- Trouble integration
							["<C-t>"] = trouble_telescope.open,

							-- Buffer operations
							["<C-x>"] = actions.delete_buffer,

							-- History navigation
							["<C-n>"] = actions.cycle_history_next,
							["<C-p>"] = actions.cycle_history_prev,
						},
						n = {
							-- Normal mode mappings
							["<Tab>"] = actions.toggle_selection + actions.move_selection_next,
							["<S-Tab>"] = actions.toggle_selection + actions.move_selection_previous,
							["<C-a>"] = actions.select_all,
							["<C-r>"] = actions.drop_all,
							["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
							["<C-l>"] = actions.send_selected_to_loclist + actions.open_loclist,
							["<C-x>"] = actions.delete_buffer,
							["dd"] = actions.delete_buffer,
						},
					},
					-- Additional default settings
					-- selection_caret = " ",
					-- multi_icon = " ",
					vimgrep_arguments = {
						"rg",
						"--color=never",
						"--no-heading",
						"--with-filename",
						"--line-number",
						"--column",
						"--smart-case",
						"--hidden",
					},
				},
			})

			-- set keymaps
			local builtin = require("telescope.builtin")

			-- Basic file operations
			vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
			vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
			vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
			vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })

			-- File history and recent files
			vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
			vim.keymap.set("n", "<leader>fc", builtin.grep_string, { desc = "Find word under cursor" })

			-- Search operations
			vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Find word" })
			vim.keymap.set("n", "<leader>fs", function()
				builtin.grep_string({ search = vim.fn.input("Grep > ") })
			end, { desc = "Grep search" })

			-- Quickfix operations
			vim.keymap.set("n", "<leader>q", builtin.quickfix, { desc = "Quickfix list" })
			vim.keymap.set("n", "<leader>l", builtin.loclist, { desc = "Location list" })

			-- Register and marks
			vim.keymap.set("n", '<leader>"', builtin.registers, { desc = "Registers" })
			vim.keymap.set("n", "<leader>m", builtin.marks, { desc = "Marks" })
		end,
	},
}
