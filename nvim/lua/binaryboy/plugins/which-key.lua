return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		delay = 300,
		icons = {
			mappings = true,
			keys = {},
		},
		spec = {
			{ "<leader>b", group = "buffer" },
			{ "<leader>c", group = "code" },
			{ "<leader>e", group = "explorer" },
			{ "<leader>f", group = "find/file" },
			{ "<leader>g", group = "git" },
			{ "<leader>h", group = "git hunks" },
			{ "<leader>l", group = "lsp" },
			{ "<leader>r", group = "debug" },
			{ "<leader>s", group = "split/search" },
			{ "<leader>t", group = "tab/terminal" },
			{ "<leader>u", group = "ui/toggle" },
			{ "<leader>x", group = "trouble" },
			{ "<leader><leader>", group = "swap buffer" },
			{ "[", group = "prev" },
			{ "]", group = "next" },
			{ "g", group = "goto" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Keymaps",
		},
	},
}
