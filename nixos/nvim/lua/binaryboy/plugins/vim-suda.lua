-- Read/write root-owned files without the broken `:w !sudo tee %` dance.
-- `:!` in Neovim has no TTY, so sudo can't prompt there; suda.vim instead
-- asks for the password in Neovim's own cmdline. Pure Vimscript, stable for
-- years (no API churn), and the de-facto standard for this.
return {
	"lambdalisue/vim-suda",
	lazy = false,
	init = function()
		-- Transparently sudo-read a file you can't read and sudo-write one you
		-- can't write: just `:edit /etc/hosts` then `:w` as usual. Falls back to
		-- a cmdline password prompt when sudo isn't already cached.
		vim.g.suda_smart_edit = 1
	end,
	keys = {
		{ "<leader>W", "<cmd>SudaWrite<CR>", desc = "Write file with sudo" },
	},
}
