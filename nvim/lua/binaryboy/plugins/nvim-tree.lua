return {
	"nvim-tree/nvim-tree.lua",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local nvimtree = require("nvim-tree")

		-- recommended settings from nvim-tree documentation
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		nvimtree.setup({
			view = {
				width = 35,
				relativenumber = true,
			},
			-- filters
			filters = {
				dotfiles = false,
				custom = { "^.git$", "^node_modules$", "^__pycache__$" },
			},
			-- git integration
			git = {
				enable = true,
				show_on_dirs = true,
			},
			-- enable diagnostics (this was disabled!)
			diagnostics = {
				enable = true,
				show_on_dirs = true,
				show_on_open_dirs = true,
				severity = {
					min = vim.diagnostic.severity.HINT,
					max = vim.diagnostic.severity.ERROR,
				},
			},
			-- modified files
			modified = {
				enable = true,
				show_on_dirs = true,
			},
			-- renderer
			renderer = {
				group_empty = true,
				highlight_git = true,
				highlight_opened_files = "name",
				highlight_modified = "name",
				indent_markers = {
					enable = true,
				},
				icons = {
					show = {
						git = true,
						folder = true,
						file = true,
						folder_arrow = true,
					},
					glyphs = {
						default = "󰈚",
						symlink = "",
						bookmark = "󰆤",
						modified = "●",
						folder = {
							default = "",
							empty = "",
							empty_open = "",
							open = "",
							symlink = "",
							symlink_open = "",
							arrow_open = "",
							arrow_closed = "",
						},
						git = {
							unstaged = "✗",
							staged = "✓",
							unmerged = "",
							renamed = "➜",
							untracked = "★",
							deleted = "",
							ignored = "◌",
						},
					},
				},
			},
			-- actions
			actions = {
				open_file = {
					quit_on_open = false,
					window_picker = {
						enable = true,
					},
				},
			},
			-- update focused file
			update_focused_file = {
				enable = true,
				update_root = false,
			},
			-- filesystem watchers
			filesystem_watchers = {
				enable = true,
			},
		})

		-- keymaps
		local keymap = vim.keymap
		keymap.set("n", "<leader>ee", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
		keymap.set(
			"n",
			"<leader>ef",
			"<cmd>NvimTreeFindFileToggle<CR>",
			{ desc = "Toggle file explorer on current file" }
		)
		keymap.set("n", "<leader>ec", "<cmd>NvimTreeCollapse<CR>", { desc = "Collapse file explorer" })
		keymap.set("n", "<leader>er", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file explorer" })
	end,
}
