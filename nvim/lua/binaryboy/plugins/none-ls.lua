return {
	"jay-babu/mason-null-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"nvimtools/none-ls.nvim",
	},
	config = function()
		local function get_sqlfluff_args()
			local args = { "--dialect", "postgres" }
			return vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
		end

		local augroup = vim.api.nvim_create_augroup("NullLsLspFormatting", {})
		require("mason").setup()
		local null_ls = require("null-ls")

		null_ls.setup({
			sources = {
				-- golang
				null_ls.builtins.formatting.gofmt,
				null_ls.builtins.formatting.goimports_reviser.with({
					extra_args = { "-company-prefixes", "git.divar.cloud/divar" },
				}),
				null_ls.builtins.diagnostics.golangci_lint,
				null_ls.builtins.formatting.gofumpt,

				-- python
				null_ls.builtins.formatting.isort,
				null_ls.builtins.formatting.black,
				null_ls.builtins.diagnostics.pylint,

				-- lua
				null_ls.builtins.formatting.stylua,

				-- sql
				null_ls.builtins.diagnostics.sqlfluff.with({ extra_args = get_sqlfluff_args() }),
				null_ls.builtins.formatting.sqlfluff.with({ extra_args = get_sqlfluff_args() }),
			},
			on_attach = function(client, bufnr)
				if client.supports_method("textDocument/formatting") then
					vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
					vim.api.nvim_create_autocmd("BufWritePre", {
						group = augroup,
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({ async = false })
						end,
					})
				end
			end,
		})

		require("mason-null-ls").setup({
			ensure_installed = {},
			automatic_installation = true,
		})

		Map("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format buffer" })
	end,
}
