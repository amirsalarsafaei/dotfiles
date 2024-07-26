return {
	"williamboman/mason.nvim",
	dependencies = {
		"jay-babu/mason-nvim-dap.nvim",
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		-- import mason
		local mason = require("mason")

		-- import mason-lspconfig
		local mason_lspconfig = require("mason-lspconfig")

		local mason_tool_installer = require("mason-tool-installer")

		local mason_nvim_dap = require("mason-nvim-dap")

		-- enable mason and configure icons
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			-- list of servers for mason to install
			ensure_installed = {
				"gopls",
				"tsserver",
				"html",
				"cssls",
				"tailwindcss",
				"lua_ls",
				"prismals",
				"pyright",
				"elixirls@v0.11.0",
				"sqls",
			},
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"prettier", -- prettier formatter
				"stylua", -- lua formatter
				"isort", -- python formatter
				"black", -- python formatter
				"pylint",
				"eslint_d",
			},
		})

		mason_nvim_dap.setup()
	end,
}
