local hostconfig = require("binaryboy.core.hostconfig")
local lsp_servers = require("binaryboy.core.lsp_servers")

if not hostconfig.mason then
	return {}
end

-- Mason package list is derived from the single registry in core/lsp_servers.lua.
return {
	{
		"williamboman/mason.nvim",
		opts = {},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		opts = {
			ensure_installed = lsp_servers.mason_packages,
			automatic_installation = false,
		},
	},
}
