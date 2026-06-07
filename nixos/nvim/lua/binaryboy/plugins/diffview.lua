local function toggle_line_history(start_line, end_line)
	local view = require("diffview.lib").get_current_view()
	if view then
		vim.cmd.DiffviewClose()
		return
	end

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	vim.cmd(("%d,%dDiffviewFileHistory %%"):format(start_line, end_line))
end

return {
	"sindrets/diffview.nvim",
	event = "VeryLazy",
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<CR>", mode = "n", desc = "Open diffview" },
		{ "<leader>gq", "<cmd>DiffviewClose<CR>", mode = "n", desc = "Close diffview" },
		{
			"<leader>gh",
			function()
				local line = vim.api.nvim_win_get_cursor(0)[1]
				toggle_line_history(line, line)
			end,
			mode = "n",
			desc = "Toggle git line history",
		},
		{
			"<leader>gh",
			function()
				toggle_line_history(vim.fn.line("v"), vim.fn.line("."))
			end,
			mode = "x",
			desc = "Toggle git selection history",
		},
	},
	config = function()
		local diffview = require("diffview")

		diffview.setup({
			enhanced_diff_hl = true,
			hooks = {
				diff_buf_read = function(bufnr)
					-- Keep diagnostics out of generated diff buffers.
					if vim.diagnostic.enable then
						vim.diagnostic.enable(false, { bufnr = bufnr })
					elseif vim.diagnostic.disable then
						vim.diagnostic.disable(bufnr)
					end
				end,
			},
		})
	end,
}
