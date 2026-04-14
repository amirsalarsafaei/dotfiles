local hostconfig = require("binaryboy.core.hostconfig")
local lsp_servers = require("binaryboy.core.lsp_servers")

if not hostconfig.mason then
	return {}
end

local lsp_to_mason = {
	lua_ls = "lua-language-server",
	gopls = "gopls",
	golangci_lint_ls = "golangci-lint-langserver",
	nixd = "nixd",
	pyright = "pyright",
	yamlls = "yaml-language-server",
	["protobuf-language-server"] = "protobuf-language-server",
	elixirls = "elixir-ls",
	lexical = "lexical",
	sqls = "sqls",
	ts_ls = "typescript-language-server",
	rust_analyzer = "rust-analyzer",
	sourcekit = "sourcekit",
	cssls = "css-lsp",
	html = "html-lsp",
	dockerls = "dockerfile-language-server",
	docker_compose_language_service = "docker-compose-language-service",
	bashls = "bash-language-server",
	clangd = "clangd",
	jdtls = "jdtls",
	systemd_ls = "systemd-language-server",
}

local ensure_lsp = {}
for _, server in ipairs(lsp_servers.all_servers) do
	local pkg = lsp_to_mason[server]
	if pkg then
		table.insert(ensure_lsp, pkg)
	end
end

return {
	{
		"williamboman/mason.nvim",
		opts = {},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		opts = {
			ensure_installed = ensure_lsp,
			automatic_installation = false,
		},
	},
}
