return {
	"ThePrimeagen/harpoon",
	config = function()
		local harpoon = require("harpoon")
		harpoon.setup()
		vim.keymap.set("n", "<leader>A", function()
			require("harpoon.mark").add_file()
		end)
		vim.keymap.set("n", "<C-e>", function()
			require("harpoon.ui").toggle_quick_menu()
		end)
	end,
}
