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
			{ "<leader>p", group = "platformio", mode = "n" },
			{ "<leader>q", group = "session" },
			{ "<leader>r", group = "run/debug" },
			{ "<leader>R", group = "search/replace" },
			{ "<leader>s", group = "split" },
			{ "<leader>t", group = "terminal/tabs" },
			{ "<leader>tn", desc = "Tab new" },
			{ "<leader>tc", desc = "Tab close" },
			{ "<leader>to", desc = "Tab only" },
			{ "<leader>t]", desc = "Tab next" },
			{ "<leader>t[", desc = "Tab previous" },
			{ "<leader>u", group = "ui/toggle" },
			{ "<leader>x", group = "trouble" },
			{ "<leader><leader>", group = "swap window" },
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
