return {
	"jay-babu/mason-null-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"nvimtools/none-ls.nvim",
	},
	config = function()
		require("mason").setup()
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.gofmt,
				null_ls.builtins.formatting.goimports_reviser,
				null_ls.builtins.diagnostics.golangci_lint,
				null_ls.builtins.formatting.isort,
				null_ls.builtins.formatting.black,
				null_ls.builtins.diagnostics.pylint.with({
					extra_args = {
						"--init-hook",
						"import pylint_venv; pylint_venv.inithook(force_venv_activation=True, quiet=True)"
					}
				})
			},
		})
		require("mason-null-ls").setup({
			ensure_installed = nil,
			automatic_installation = true,
		})

		Map("n", "<leader>gf", vim.lsp.buf.format, { desc = "formats buffer" })
	end,
}
