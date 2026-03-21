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

local server_bins = {
	lua_ls = { "lua-language-server" },
	gopls = { "gopls" },
	golangci_lint_ls = { "golangci-lint-langserver" },
	nixd = { "nixd" },
	pyright = { "pyright-langserver", "pyright" },
	yamlls = { "yaml-language-server" },
	["protobuf-language-server"] = { "protobuf-language-server" },
	elixirls = { "elixir-ls", "elixirls" },
	lexical = { "lexical" },
	sqls = { "sqls" },
	ts_ls = { "typescript-language-server" },
	rust_analyzer = { "rust-analyzer" },
	sourcekit = { "sourcekit-lsp" },
	cssls = { "vscode-css-language-server" },
	html = { "vscode-html-language-server" },
	dockerls = { "docker-langserver" },
	docker_compose_language_service = { "docker-compose-langserver" },
	bashls = { "bash-language-server" },
	clangd = { "clangd" },
	jdtls = { "jdtls", "jdt-language-server" },
}

local all_servers = {
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
}

local available = vim.tbl_filter(function(server)
	local candidates = server_bins[server] or { server }
	for _, bin in ipairs(candidates) do
		if vim.fn.executable(bin) == 1 then
			return true
		end
	end
	return false
end, all_servers)

vim.lsp.enable(available)
