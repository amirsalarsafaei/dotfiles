return {
	"nvimtools/none-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local ok, null_ls = pcall(require, "null-ls")
		if not ok then
			return
		end

		local fmt = null_ls.builtins.formatting
		local diag = null_ls.builtins.diagnostics

		local function has(cmd)
			return vim.fn.executable(cmd) == 1
		end

		local function get_sqlfluff_args()
			local args = { "--dialect", "postgres" }
			local config_path = vim.fn.getcwd() .. "/.sqlfluff"
			if vim.fn.filereadable(config_path) == 1 then
				vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
			end
			return args
		end

		local sources = {}

		if has("prettier") then
			table.insert(sources, fmt.prettier.with({
				filetypes = { "markdown", "json", "yaml", "markdown.mdx" },
			}))
		end

		if has("shfmt") then
			table.insert(sources, fmt.shfmt.with({ extra_args = { "-i", "2", "-ci" } }))
		end

		if has("yamllint") then
			table.insert(sources, diag.yamllint)
		end

		if has("hadolint") then
			table.insert(sources, diag.hadolint)
		end

		if has("gofmt") then
			table.insert(sources, fmt.gofmt)
		end

		if has("goimports-reviser") then
			table.insert(sources, fmt.goimports_reviser.with({
				extra_args = { "-company-prefixes", "git.divar.cloud/divar" },
			}))
		end

		if has("isort") then
			table.insert(sources, fmt.isort)
		end

		if has("black") then
			table.insert(sources, fmt.black)
		end

		if has("rustfmt") then
			table.insert(sources, fmt.rustfmt)
		end

		if has("stylua") then
			table.insert(sources, fmt.stylua)
		end

		if has("sqlfluff") then
			table.insert(sources, diag.sqlfluff.with({ extra_args = get_sqlfluff_args() }))
			table.insert(sources, fmt.sqlfluff.with({ extra_args = get_sqlfluff_args() }))
		end

		if has("buf") then
			table.insert(sources, fmt.buf)
		end

		null_ls.setup({
			debounce = 150,
			sources = sources,
		})

		vim.keymap.set("n", "<leader>gf", function()
			vim.lsp.buf.format({ async = true })
		end, { desc = "Format buffer" })
	end,
}
