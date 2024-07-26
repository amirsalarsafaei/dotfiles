return {
	"jay-babu/mason-null-ls.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"nvimtools/none-ls.nvim",
	},
	config = function()
		local Path = require("plenary.path")

		local function find_parent_folder_with_file(start_path, filename)
			local current_path = Path:new(start_path):absolute()

			while true do
				local target_file = Path:new(current_path, filename)
				if target_file:exists() then
					return current_path
				end

				-- Move to the parent directory.
				local parent_path = Path:new(current_path):parent():absolute()

				if parent_path == current_path then
					-- If the parent path is the same as the current path, we've reached the root.
					return nil
				end

				current_path = parent_path
			end
		end

		local sqlfluff_args = { "--dialect", "postgres" }
		local sqlfluff_config_root = find_parent_folder_with_file(vim.fn.expand("%:p"), ".sqlfluff")
		if sqlfluff_config_root then
			vim.list_extend(sqlfluff_args, { "--config", sqlfluff_config_root })
		end

		local augroup = vim.api.nvim_create_augroup("NullLsLspFormatting", {})
		require("mason").setup()
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				-- golang
				null_ls.builtins.formatting.gofmt,
				null_ls.builtins.formatting.goimports_reviser.with({
					extra_args = {
						"-company-prefixes",
						"git.divar.cloud/divar",
					},
				}),
				null_ls.builtins.diagnostics.golangci_lint,
				null_ls.builtins.formatting.gofumpt,
				-- python
				null_ls.builtins.formatting.isort,
				null_ls.builtins.formatting.black,
				null_ls.builtins.diagnostics.pylint.with({
					extra_args = {
						"--init-hook",
						"import pylint_venv; pylint_venv.inithook(force_venv_activation=True, quiet=True)",
					},
				}),
				-- lua
				null_ls.builtins.formatting.stylua,
				-- sql
				null_ls.builtins.diagnostics.sqlfluff.with({
					extra_args = sqlfluff_args, -- change to your dialect
				}),

				null_ls.builtins.formatting.sqlfluff.with({
					extra_args = sqlfluff_args, -- change to your dialect
				}),
				-- general
				null_ls.builtins.diagnostics.codespell,
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

		Map("n", "<leader>gf", vim.lsp.buf.format, { desc = "formats buffer" })
	end,
}
