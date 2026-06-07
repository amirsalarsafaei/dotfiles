return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{ "<leader>A", function() require("harpoon"):list():add() end, desc = "Harpoon add file" },
		{ "<C-e>", function() local harpoon = require("harpoon") harpoon.ui:toggle_quick_menu(harpoon:list()) end, desc = "Harpoon menu" },
		{ "<C-1>", function() require("harpoon"):list():select(1) end, desc = "Harpoon file 1" },
		{ "<C-2>", function() require("harpoon"):list():select(2) end, desc = "Harpoon file 2" },
		{ "<C-3>", function() require("harpoon"):list():select(3) end, desc = "Harpoon file 3" },
		{ "<C-4>", function() require("harpoon"):list():select(4) end, desc = "Harpoon file 4" },
		{ "<C-5>", function() require("harpoon"):list():select(5) end, desc = "Harpoon file 5" },
	},
	opts = {
		settings = {
			save_on_toggle = true,
			sync_on_ui_close = true,
		},
	},
}
