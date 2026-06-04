return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"mfussenegger/nvim-dap",
		{ "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
	},
	ft = "python",
	keys = {
		{ ",v", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
	},
	opts = {},
}
