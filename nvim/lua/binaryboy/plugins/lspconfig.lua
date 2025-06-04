return {
	{
		"folke/neodev.nvim",
		ft = "lua", -- only load on lua files
		opts = {
			library = {
				plugins = { "neotest" },
				types = true,
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
			"nanotee/sqls.nvim",
			{ "j-hui/fidget.nvim",                   opts = {} }, -- Use opts for simpler setup
		},
		config = function()
			-- Core requirements
			local cmp_nvim_lsp = require("cmp_nvim_lsp")
			local keymap = vim.keymap

			-----------------------------------------------------------
			-- LSP Keybindings
			-----------------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					local bufnr = ev.buf

					-- Navigation
					keymap.set(
						"n",
						"gR",
						"<cmd>Telescope lsp_references include_declaration=false<CR>",
						{ buffer = bufnr, desc = "Show LSP references" }
					)
					keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Go to declaration" })
					keymap.set(
						"n",
						"gd",
						"<cmd>Telescope lsp_definitions<CR>",
						{ buffer = bufnr, desc = "Show LSP definitions" }
					)
					keymap.set(
						"n",
						"gi",
						"<cmd>Telescope lsp_implementations<CR>",
						{ buffer = bufnr, desc = "Show LSP implementations" }
					)
					keymap.set(
						"n",
						"gt",
						"<cmd>Telescope lsp_type_definitions<CR>",
						{ buffer = bufnr, desc = "Show LSP type definitions" }
					)

					-- Information
					keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						{ buffer = bufnr, desc = "Show documentation for what is under cursor" }
					)
					keymap.set("n", "gs", vim.lsp.buf.signature_help, { buffer = bufnr, desc = "Show signature help" })

					-- Code actions
					keymap.set(
						{ "n", "v" },
						"<leader>ca",
						vim.lsp.buf.code_action,
						{ buffer = bufnr, desc = "See available code actions" }
					)
					keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = bufnr, desc = "Smart rename" })

					-- Diagnostics
					keymap.set(
						"n",
						"<leader>D",
						"<cmd>Telescope diagnostics bufnr=0<CR>",
						{ buffer = bufnr, desc = "Show buffer diagnostics" }
					)
					keymap.set(
						"n",
						"<leader>d",
						vim.diagnostic.open_float,
						{ buffer = bufnr, desc = "Show line diagnostics" }
					)
					keymap.set(
						"n",
						"[d",
						vim.diagnostic.goto_prev,
						{ buffer = bufnr, desc = "Go to previous diagnostic" }
					)
					keymap.set("n", "]d", vim.diagnostic.goto_next, { buffer = bufnr, desc = "Go to next diagnostic" })

					-- Utility
					keymap.set("n", "<leader>rs", ":LspRestart<CR>", { buffer = bufnr, desc = "Restart LSP" })

					-- Inlay hints (Neovim 0.10+)
					if client and client:supports_method("textDocument/inlayHint") then
						-- Toggle inlay hints with <leader>ih
						keymap.set("n", "<leader>ih", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = bufnr }))
						end, { buffer = bufnr, desc = "Toggle inlay hints" })
					end
				end,
			})

			-----------------------------------------------------------
			-- LSP Diagnostics Configuration
			-----------------------------------------------------------
			-- Used to enable autocompletion (assign to every lsp server config)
			local capabilities = cmp_nvim_lsp.default_capabilities()

			-- Enable completions for all file operations
			capabilities.workspace = {
				fileOperations = {
					didCreate = true,
					didRename = true,
					didDelete = true,
					willCreate = true,
					willRename = true,
					willDelete = true,
				},
			}

			-- Diagnostic symbols in the sign column (gutter)
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			vim.diagnostic.config({
				update_in_insert = true,
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
				severity_sort = true,
				virtual_text = {
					prefix = "●", -- Could be '■', '▎', 'x'
					source = "if_many",
				},
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = signs.Error,
						[vim.diagnostic.severity.WARN] = signs.Warn,
						[vim.diagnostic.severity.HINT] = signs.Hint,
						[vim.diagnostic.severity.INFO] = signs.Info,
					},
				},
			})
		end,
	},
}
