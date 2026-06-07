return {
	"akinsho/toggleterm.nvim",
	version = "*",
	cmd = "ToggleTerm",
	keys = {
		{ "<leader>tt", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Terminal horizontal" },
		{ "<leader>tv", "<cmd>ToggleTerm direction=vertical size=80<CR>", desc = "Terminal vertical" },
		{ "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", desc = "Terminal float" },
		{ "<C-\\>", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal", mode = { "n", "t" } },
	},
	opts = {
		size = function(term)
			if term.direction == "horizontal" then
				return 15
			elseif term.direction == "vertical" then
				return vim.o.columns * 0.4
			end
		end,
		hide_numbers = true,
		shade_terminals = true,
		shading_factor = 2,
		start_in_insert = true,
		insert_mappings = true,
		persist_size = true,
		close_on_exit = true,
		shell = vim.o.shell,
		float_opts = {
			border = "curved",
			winblend = 0,
		},
		winbar = {
			enabled = false,
		},
	},
	config = function(_, opts)
		require("toggleterm").setup(opts)

		vim.api.nvim_create_autocmd("TermOpen", {
			pattern = "term://*toggleterm#*",
			callback = function()
				local map = vim.keymap.set
				local buf_opts = { buffer = 0 }
				map("t", "<Esc><Esc>", [[<C-\><C-n>]], buf_opts)
				map("t", "<C-h>", [[<Cmd>wincmd h<CR>]], buf_opts)
				map("t", "<C-j>", [[<Cmd>wincmd j<CR>]], buf_opts)
				map("t", "<C-k>", [[<Cmd>wincmd k<CR>]], buf_opts)
				map("t", "<C-l>", [[<Cmd>wincmd l<CR>]], buf_opts)
			end,
		})
	end,
}
