return {
	"harrisoncramer/gitlab.nvim",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"nvim-tree/nvim-web-devicons", -- Recommended but not required. Icons in discussion tree.
	},
	enabled = true,
	build = function()
		require("gitlab.server").build(true)
	end, -- Builds the Go binary
	config = function()
		local gitlab = require("gitlab")
		gitlab.setup()
		vim.keymap.set("n", "glnc", gitlab.create_comment, { desc = "creates gitlab git merge request comment", noremap = true, silent = true })
	end,
}
