return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "NvimTreeToggle", "NvimTreeFindFileToggle" },
	keys = {
		{ "<leader>ee", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
		{ "<leader>ef", "<cmd>NvimTreeFindFileToggle<CR>", desc = "Find file in explorer" },
		{ "<leader>ec", "<cmd>NvimTreeCollapse<CR>", desc = "Collapse explorer" },
		{ "<leader>er", "<cmd>NvimTreeRefresh<CR>", desc = "Refresh explorer" },
	},
	init = function()
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1
	end,
	opts = {
		-- netrw is disabled in init() above; turning off nvim-tree's directory
		-- hijack avoids an upstream bug where its BufEnter autocmd calls
		-- nvim_buf_get_name() on already-wiped scratch buffers (autocmd.lua:57,
		-- missing the validity guard that line 116 has). Trade-off: `nvim <dir>`
		-- no longer auto-opens the tree.
		hijack_directories = { enable = false },
		hijack_netrw = false,
		view = {
			width = 35,
			relativenumber = true,
		},
		filters = {
			dotfiles = false,
			git_ignored = false,
			custom = { "^.git$", "^node_modules$", "^__pycache__$", "^\\.DS_Store$" },
		},
		git = {
			enable = true,
			show_on_dirs = true,
		},
		diagnostics = {
			enable = true,
			show_on_dirs = true,
			show_on_open_dirs = true,
		},
		modified = {
			enable = true,
			show_on_dirs = true,
		},
		renderer = {
			group_empty = true,
			highlight_git = true,
			highlight_opened_files = "name",
			highlight_modified = "name",
			indent_markers = { enable = true },
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
					folder = {
						default = "",
						empty = "",
						empty_open = "",
						open = "",
						symlink = "",
						symlink_open = "",
						arrow_open = "",
						arrow_closed = "",
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
		actions = {
			open_file = {
				quit_on_open = false,
				window_picker = { enable = true },
			},
		},
		update_focused_file = {
			enable = true,
			update_root = false,
		},
	},
}
