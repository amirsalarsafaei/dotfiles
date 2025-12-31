return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	lazy = false,
	opts = {
		flavour = "mocha",
		transparent_background = false,
		term_colors = true,
		dim_inactive = {
			enabled = false,
		},
		styles = {
			comments = { "italic" },
			conditionals = { "italic" },
		},
		integrations = {
			alpha = true,
			blink_cmp = true,
			diffview = true,
			fidget = true,
			gitsigns = true,
			harpoon = true,
			indent_blankline = { enabled = true },
			lsp_trouble = true,
			mason = true,
			native_lsp = {
				enabled = true,
				underlines = {
					errors = { "undercurl" },
					hints = { "undercurl" },
					warnings = { "undercurl" },
					information = { "undercurl" },
				},
			},
			nvimtree = true,
			telescope = { enabled = true },
			treesitter = true,
			which_key = true,
		},
	},
	config = function(_, opts)
		require("catppuccin").setup(opts)
		vim.cmd.colorscheme("catppuccin")
		pcall(function()
			require("avante_lib").load()
		end)
	end,
}
