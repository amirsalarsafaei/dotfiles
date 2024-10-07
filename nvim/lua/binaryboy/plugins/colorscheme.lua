return {
	"catppuccin/nvim",
	priority = 1000,
	config = function()
		local theme = require("catppuccin")
		theme.setup({
			integrations = {
				diffview = true,
				mason = true,
				lsp_trouble = true,
			},
		})
		vim.cmd.colorscheme("catppuccin")
		require("avante_lib").load()
	end,
}
