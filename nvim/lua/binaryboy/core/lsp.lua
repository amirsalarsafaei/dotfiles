vim.lsp.config("*", {
	capabilities = {
		textDocument = {
			completion = {
				completionItem = {
					snippetSupport = true,
					resolveSupport = {
						properties = { "documentation", "detail", "additionalTextEdits" },
					},
				},
			},
		},
		workspace = {
			didChangeWatchedFiles = {
				dynamicRegistration = true,
			},
			fileOperations = {
				didCreate = true,
				didRename = true,
				didDelete = true,
			},
		},
	},
})

vim.lsp.enable({
	"lua_ls",
	"gopls",
	"golangci_lint_ls",
	"nixd",
	"pyright",
	"yamlls",
	"protobuf-language-server",
	"elixirls",
	"lexical",
	"sqls",
	"ts_ls",
	"rust_analyzer",
	"sourcekit",
	"cssls",
	"html",
	"dockerls",
	"docker_compose_language_service",
	"bashls",
	"clangd",
	"jdtls",
})
