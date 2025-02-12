return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			size = 20,
			open_mapping = [[<leader>tt]],
			direction = "horizontal",
			hide_numbers = true,
			shade_terminals = true,
			shading_factor = 2,
			start_in_insert = false,
			insert_mappings = false,
			persist_size = true,
			close_on_exit = true,
			shell = vim.o.shell,
			float_opts = {
				border = "curved",
				winblend = 0,
				highlights = {
					border = "Normal",
					background = "Normal",
				},
			},
		})

		-- Terminal keymaps when inside terminal
		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
		end

		-- Auto command to set terminal keymaps when terminal opens
		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
	end,
}
