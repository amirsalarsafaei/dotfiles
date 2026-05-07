return {
	"nmac427/guess-indent.nvim",
	config = function()
		require("guess-indent").setup({
			filetype_exclude = {
				"c", "cpp", "objc", "objcpp", "cuda",
				"netrw", "tutor",
			},
		})
	end,
}
