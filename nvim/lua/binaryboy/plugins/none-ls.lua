return {
	"nvimtools/none-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local null_ls = require("null-ls")
		local fmt = null_ls.builtins.formatting
		local diag = null_ls.builtins.diagnostics

		local function get_sqlfluff_args()
			local args = { "--dialect", "postgres" }
			local config_path = vim.fn.getcwd() .. "/.sqlfluff"
			if vim.fn.filereadable(config_path) == 1 then
				vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
			end
			return args
		end

		null_ls.setup({
			debounce = 150,
			sources = {
				fmt.prettier.with({
					filetypes = { "markdown", "json", "yaml", "markdown.mdx" },
				}),

				fmt.shfmt.with({ extra_args = { "-i", "2", "-ci" } }),

				diag.yamllint,

				diag.hadolint,

				fmt.gofmt,
				fmt.goimports_reviser.with({
					extra_args = { "-company-prefixes", "git.divar.cloud/divar" },
				}),

				fmt.isort,
				fmt.black,

				fmt.rustfmt,

				fmt.stylua,

				diag.sqlfluff.with({ extra_args = get_sqlfluff_args() }),
				fmt.sqlfluff.with({ extra_args = get_sqlfluff_args() }),

				fmt.buf,
			},
		})

		vim.keymap.set("n", "<leader>gf", function()
			vim.lsp.buf.format({ async = true })
		end, { desc = "Format buffer" })
	end,
}
