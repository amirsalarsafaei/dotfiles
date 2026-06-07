local lsp_servers = require("binaryboy.core.lsp_servers")

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

local available = vim.tbl_filter(function(server)
	local candidates = lsp_servers.server_bins[server] or { server }
	for _, bin in ipairs(candidates) do
		if vim.fn.executable(bin) == 1 then
			return true
		end
	end
	return false
end, lsp_servers.all_servers)

vim.lsp.enable(available)
