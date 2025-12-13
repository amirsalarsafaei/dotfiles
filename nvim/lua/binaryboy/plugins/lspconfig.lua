return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "luvit-meta/library", words = { "vim%.uv" } },
			},
		},
	},
	{ "Bilal2453/luvit-meta", lazy = true },
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{ "j-hui/fidget.nvim",                   opts = {} },
			{ "antosha417/nvim-lsp-file-operations", config = true },
		},
		config = function()
			local lspconfig = require("lspconfig")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			-----------------------------------------------------------
			-- 1. General UI & Diagnostics
			-----------------------------------------------------------
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			vim.diagnostic.config({
				update_in_insert = false,
				severity_sort = true, -- Added: sorts diagnostics by priority
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			})

			-- Border adjustments for hover/signature
			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
			vim.lsp.handlers["textDocument/signatureHelp"] =
					vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

			-----------------------------------------------------------
			-- 2. Capabilities (Completion & File Ops)
			-----------------------------------------------------------
			local capabilities = vim.tbl_deep_extend(
				"force",
				vim.lsp.protocol.make_client_capabilities(),
				cmp_nvim_lsp.default_capabilities(),
				{
					workspace = {
						fileOperations = {
							didCreate = true,
							didRename = true,
							didDelete = true,
						},
					},
				}
			)

			-----------------------------------------------------------
			-- 3. LspAttach (Keymaps & Highlights)
			-----------------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					local bufnr = ev.buf

					-- Guard against special buffers
					if vim.api.nvim_buf_get_name(bufnr):match("^fugitive://") then
						return
					end

					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = "LSP: " .. desc })
					end

					-- Standard Keymaps
					map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
					map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
					map("n", "gr", vim.lsp.buf.references, "References")
					map("n", "gi", vim.lsp.buf.implementation, "Implementations")
					map("n", "gt", vim.lsp.buf.type_definition, "Type Definition")
					map("n", "K", vim.lsp.buf.hover, "Hover Doc")
					map("n", "gs", vim.lsp.buf.signature_help, "Signature Help")
					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
					map("n", "<leader>d", vim.diagnostic.open_float, "Line Diagnostics")
					map("n", "[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
					map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")

					-- Inlay Hints (Neovim 0.10+)
					if client and client.supports_method("textDocument/inlayHint") and vim.lsp.inlay_hint then
						vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
						map("n", "<leader>th", function()
							local current = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
							vim.lsp.inlay_hint.enable(not current, { bufnr = bufnr })
						end, "Toggle Inlay Hints")
					end

					-- Document Highlighting (Fixed logic)
					if client and client.supports_method("textDocument/documentHighlight") then
						local highlight_augroup = vim.api.nvim_create_augroup("UserLspHighlight", { clear = false })

						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = bufnr,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = bufnr,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("UserLspDetach", { clear = true }),
							callback = function(event)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "UserLspHighlight", buffer = event.buf })
							end,
						})
					end
				end,
			})
		end,
	},
}
