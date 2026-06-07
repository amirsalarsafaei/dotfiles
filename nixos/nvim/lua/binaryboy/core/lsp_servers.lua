local M = {}

-- Single source of truth for language servers.
--   bins  = PATH executables that satisfy the server; the first one found wins
--           (resolution happens in core/lsp.lua against Nix-provided binaries).
--   mason = mason.nvim package name, used ONLY when a host opts into Mason
--           instead of Nix (hostconfig.mason; see plugins/mason.lua). Omit when
--           Mason has no equivalent package.
M.servers = {
	lua_ls = { bins = { "lua-language-server" }, mason = "lua-language-server" },
	gopls = { bins = { "gopls" }, mason = "gopls" },
	golangci_lint_ls = { bins = { "golangci-lint-langserver" }, mason = "golangci-lint-langserver" },
	nixd = { bins = { "nixd" }, mason = "nixd" },
	pyright = { bins = { "pyright-langserver", "pyright" }, mason = "pyright" },
	yamlls = { bins = { "yaml-language-server" }, mason = "yaml-language-server" },
	["protobuf-language-server"] = { bins = { "protobuf-language-server" }, mason = "protobuf-language-server" },
	elixirls = { bins = { "elixir-ls", "elixirls" }, mason = "elixir-ls" },
	lexical = { bins = { "lexical" }, mason = "lexical" },
	sqls = { bins = { "sqls" }, mason = "sqls" },
	ts_ls = { bins = { "typescript-language-server" }, mason = "typescript-language-server" },
	rust_analyzer = { bins = { "rust-analyzer" }, mason = "rust-analyzer" },
	sourcekit = { bins = { "sourcekit-lsp" }, mason = "sourcekit" },
	cssls = { bins = { "vscode-css-language-server" }, mason = "css-lsp" },
	html = { bins = { "vscode-html-language-server" }, mason = "html-lsp" },
	dockerls = { bins = { "docker-langserver" }, mason = "dockerfile-language-server" },
	docker_compose_language_service = { bins = { "docker-compose-langserver" }, mason = "docker-compose-language-service" },
	bashls = { bins = { "bash-language-server" }, mason = "bash-language-server" },
	clangd = { bins = { "clangd" }, mason = "clangd" },
	jdtls = { bins = { "jdtls", "jdt-language-server" }, mason = "jdtls" },
	systemd_ls = { bins = { "systemd-language-server" }, mason = "systemd-language-server" },
}

-- Derived views (stable, sorted) for the consumers in core/lsp.lua and
-- plugins/mason.lua. Edit M.servers above; never these.
M.all_servers = {}
M.server_bins = {}
M.mason_packages = {}

for name, spec in pairs(M.servers) do
	table.insert(M.all_servers, name)
	M.server_bins[name] = spec.bins
	if spec.mason then
		table.insert(M.mason_packages, spec.mason)
	end
end

table.sort(M.all_servers)
table.sort(M.mason_packages)

return M
