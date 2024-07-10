return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"williamboman/mason.nvim",
		"jay-babu/mason-nvim-dap.nvim",
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		"leoluz/nvim-dap-go",
	},
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")
		local dap_go = require("dap-go")

		dap_go.setup({
			delve = {
				initialize_timeout_sec = 30,
			},
		})
		dapui.setup()

		-- adding dap ui attachments
		dap.listeners.before.attach.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.launch.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated.dapui_config = function()
			dapui.close()
		end
		dap.listeners.before.event_exited.dapui_config = function()
			dapui.close()
		end

		Map("n", "<Leader>db", dap.toggle_breakpoint, {})
		Map("n", "<Leader>dc", dap.continue, {})
		Map("n", "<Leader>dt", dap_go.debug_test, {})
	end,
}
