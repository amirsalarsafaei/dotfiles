local hostconfig = require("binaryboy.core.hostconfig")

return {
	"zbirenbaum/copilot.lua",
	enabled = hostconfig.ai,
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = { enabled = false },
			panel = { enabled = false },
			filetypes = {
				yaml = false,
				markdown = false,
				help = false,
				gitcommit = false,
				gitrebase = false,
				hgcommit = false,
				svn = false,
				cvs = false,
				["."] = false,
			},
		})
	end,
}
