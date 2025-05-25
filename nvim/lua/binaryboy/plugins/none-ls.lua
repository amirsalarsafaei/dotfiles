return {
	"nvimtools/none-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local function get_sqlfluff_args()
			local args = { "--dialect", "postgres" }
			-- Check if .sqlfluff config exists in the project root
			local root = vim.fn.getcwd()
			local config_path = root .. "/.sqlfluff"

			if vim.fn.filereadable(config_path) == 1 then
				return vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
			end

			return args
		end

		local augroup = vim.api.nvim_create_augroup("NullLsLspFormatting", {})
		local null_ls = require("null-ls")

		local sqlfluff_args = get_sqlfluff_args()

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

				-- javascript/typescript
				null_ls.builtins.formatting.eslint,

				-- docker
				null_ls.builtins.diagnostics.hadolint,

				-- git commits
				null_ls.builtins.diagnostics.commitlint,

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
				null_ls.builtins.diagnostics.sqlfluff.with({ extra_args = sqlfluff_args }),
				null_ls.builtins.formatting.sqlfluff.with({ extra_args = sqlfluff_args }),

				null_ls.builtins.formatting.buf,
			},
			on_attach = function(client, bufnr)
				if client:supports_method("textDocument/formatting") then
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

		vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, { desc = "Format buffer", noremap = true, silent = true })
	end,
}
