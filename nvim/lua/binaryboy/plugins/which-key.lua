return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
	config = function()
		local wk = require("which-key")
		wk.add({
			{ "<leader>e", group = "file explorer" },
			{ "<leader>f", group = "search" },
			{ "<leader>h", group = "git hunks" },
			{ "<leader>x", group = "trouble" },
			{ "<leader>r", group = "debugging" },
		})
	end,
}
