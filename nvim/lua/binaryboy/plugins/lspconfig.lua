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
			"saghen/blink.cmp",
			{ "j-hui/fidget.nvim", opts = {} },
			{ "antosha417/nvim-lsp-file-operations", config = true },
		},
		config = function()
			vim.diagnostic.config({
				virtual_text = {
					spacing = 4,
					prefix = "●",
				},
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = " ",
						[vim.diagnostic.severity.WARN] = " ",
						[vim.diagnostic.severity.HINT] = "󰠠 ",
						[vim.diagnostic.severity.INFO] = " ",
					},
				},
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = true,
					header = "",
					prefix = "",
				},
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					local bufnr = ev.buf

					if vim.api.nvim_buf_get_name(bufnr):match("^fugitive://") then
						return
					end

					local function map(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
					end

					map("n", "gd", vim.lsp.buf.definition, "Definition")
					map("n", "gD", vim.lsp.buf.declaration, "Declaration")
					map("n", "gr", vim.lsp.buf.references, "References")
					map("n", "gi", vim.lsp.buf.implementation, "Implementation")
					map("n", "gy", vim.lsp.buf.type_definition, "Type Definition")
					map("n", "K", vim.lsp.buf.hover, "Hover")
					map("n", "gs", vim.lsp.buf.signature_help, "Signature Help")
					map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")
					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
					map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
					map("n", "<leader>d", vim.diagnostic.open_float, "Line Diagnostics")
					map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, "Prev Diagnostic")
					map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next Diagnostic")
					map("n", "<leader>q", vim.diagnostic.setloclist, "Diagnostics to Loclist")

					if client and client:supports_method("textDocument/inlayHint") then
						vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
						map("n", "<leader>uh", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
						end, "Toggle Inlay Hints")
					end

					if client and client:supports_method("textDocument/documentHighlight") then
						local hl_group = vim.api.nvim_create_augroup("LspHighlight_" .. bufnr, { clear = true })

						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = bufnr,
							group = hl_group,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = bufnr,
							group = hl_group,
							callback = vim.lsp.buf.clear_references,
						})
					end
				end,
			})
		end,
	},
}
