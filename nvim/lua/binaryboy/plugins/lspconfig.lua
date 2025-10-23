return {
	{
		"folke/neodev.nvim",
		ft = "lua",
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
			"folke/neodev.nvim",
			{ "antosha417/nvim-lsp-file-operations", config = true },
			{ "j-hui/fidget.nvim", opts = {} },
		},
		config = function()
			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			-----------------------------------------------------------
			-- Default Capabilities (exported for language configs)
			-----------------------------------------------------------
			local capabilities = cmp_nvim_lsp.default_capabilities()
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

			-- Make capabilities globally accessible
			_G.lsp_capabilities = capabilities

			-----------------------------------------------------------
			-- Diagnostic Configuration
			-----------------------------------------------------------
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }

			vim.diagnostic.config({
				update_in_insert = false,
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
					prefix = "●",
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

			-----------------------------------------------------------
			-- LSP Keybindings (applied on attach)
			-----------------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					local bufnr = ev.buf

					-- Helper function for setting keymaps
					local function map(modes, lhs, rhs, desc)
						vim.keymap.set(modes, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
					end

					-- Navigation
					map("n", "gR", vim.lsp.buf.references, "LSP: References")
					map("n", "gD", vim.lsp.buf.declaration, "LSP: Declaration")
					map("n", "gd", vim.lsp.buf.definition, "LSP: Definitions")
					map("n", "gi", vim.lsp.buf.implementation, "LSP: Implementations")
					map("n", "gt", vim.lsp.buf.type_definition, "LSP: Type definitions")

					-- Information
					map("n", "K", vim.lsp.buf.hover, "LSP: Hover documentation")
					map("n", "gs", vim.lsp.buf.signature_help, "LSP: Signature help")

					-- Code actions
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "LSP: Code actions")
					map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: Rename")

					-- Diagnostics
					map("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", "LSP: Buffer diagnostics")
					map("n", "<leader>d", vim.diagnostic.open_float, "LSP: Line diagnostics")
					map("n", "[d", vim.diagnostic.goto_prev, "LSP: Previous diagnostic")
					map("n", "]d", vim.diagnostic.goto_next, "LSP: Next diagnostic")

					-- Utility
					map("n", "<leader>rs", "<cmd>LspRestart<CR>", "LSP: Restart")
					map("n", "<leader>li", "<cmd>LspInfo<CR>", "LSP: Info")

					-- Inlay hints (Neovim 0.10+)
					if client and client.supports_method("textDocument/inlayHint") then
						-- Enable inlay hints by default (optional)
						vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })

						map("n", "<leader>ih", function()
							local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
							vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
						end, "LSP: Toggle inlay hints")
					end

					-- Document highlighting
					if client and client.supports_method("textDocument/documentHighlight") then
						local highlight_augroup = vim.api.nvim_create_augroup("LspDocumentHighlight", { clear = false })
						vim.api.nvim_clear_autocmds({ buffer = bufnr, group = highlight_augroup })

						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							group = highlight_augroup,
							buffer = bufnr,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							group = highlight_augroup,
							buffer = bufnr,
							callback = vim.lsp.buf.clear_references,
						})
					end

					-- Organize imports on save (TypeScript/Go)
					if client and client.supports_method("textDocument/codeAction") then
						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = bufnr,
							callback = function()
								-- Only for specific filetypes
								local ft = vim.bo[bufnr].filetype
								if ft == "go" or ft == "typescript" or ft == "typescriptreact" then
									vim.lsp.buf.code_action({
										context = { only = { "source.organizeImports" } },
										apply = true,
									})
								end
							end,
						})
					end
				end,
			})

			-----------------------------------------------------------
			-- UI Customization
			-----------------------------------------------------------
			-- Rounded borders for hover and signature help
			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
				border = "rounded",
			})

			vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
				border = "rounded",
			})
		end,
	},
}
