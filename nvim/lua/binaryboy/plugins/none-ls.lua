return {
	"jay-babu/mason-null-ls.nvim",
	Gvent = { "BufReadPre", "BufNewFile" },
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
			debounce = 150, -- Debounce formatting requests
			sources = {
				-- markdown
				null_ls.builtins.formatting.prettier.with({
					filetypes = { "markdown", "json", "yaml", "markdown.mdx" },
				}),

				-- shell scripts
				null_ls.builtins.formatting.shfmt.with({
					extra_args = { "-i", "2", "-ci" },
				}),

				-- yaml/json
				null_ls.builtins.formatting.yamlfmt,
				null_ls.builtins.diagnostics.yamllint,

				-- docker
				null_ls.builtins.diagnostics.hadolint,

				-- git commits
				null_ls.builtins.diagnostics.commitlint,

				-- spelling
				null_ls.builtins.diagnostics.codespell.with({
					filetypes = { "markdown", "text" },
				}),

				-- golang
				null_ls.builtins.formatting.gofmt,
				null_ls.builtins.formatting.goimports_reviser.with({
					extra_args = { "-company-prefixes", "git.divar.cloud/divar" },
				}),
				null_ls.builtins.diagnostics.golangci_lint,

				-- python
				null_ls.builtins.formatting.isort,
				null_ls.builtins.formatting.black,
				null_ls.builtins.diagnostics.pylint.with({
					extra_args = {
						"--init-hook",
						"import pylint_venv; pylint_venv.inithook(force_venv_activation=True)",
					},
				}),

				-- lua
				null_ls.builtins.formatting.stylua,

				-- sql
				null_ls.builtins.diagnostics.sqlfluff.with({ extra_args = get_sqlfluff_args() }),
				null_ls.builtins.formatting.sqlfluff.with({ extra_args = get_sqlfluff_args() }),

				null_ls.builtins.formatting.buf,
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
			automatic_installation = true,
			handlers = {
				buf = function()
					-- Do nothing for buf formatter
				end,
			},
		})

		Map("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format buffer" })
	end,
}
