return {
	{
		"microsoft/vscode-js-debug",
		build = "npm ci --loglevel=error && npx gulp vsDebugServerBundle && rm -rf ./out && mv dist out",
		version = "1.*",
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"williamboman/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"leoluz/nvim-dap-go",
			"mxsdev/nvim-dap-vscode-js",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")
			local dap_go = require("dap-go")
			local dap_js = require("dap-vscode-js")

			dap_go.setup({
				delve = {
					initialize_timeout_sec = 30,
				},
				dap_configurations = {
					type = "go",
				},
			})

			dap_js.setup({
				debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
				adapters = { "pwa-node", "pwa-chrome", "node", "chrome" },
			})
			local js_based_languages = { "typescript", "javascript", "typescriptreact", "javascriptreact" }

			for _, language in ipairs(js_based_languages) do
				dap.configurations[language] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Launch file",
						program = "${file}",
						cwd = "${workspaceFolder}",
						sourceMaps = true,
					},
					{
						type = "pwa-node",
						request = "attach",
						name = "Attach",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
					{
						type = "pwa-chrome",
						request = "launch",
						name = 'Start Chrome with "localhost"',
						url = function()
							local co = coroutine.running()
							return coroutine.create(function()
								vim.ui.input({
									prompt = "Enter URL: ",
									default = "http://localhost:5173",
								}, function(url)
									if url == nil or url == "" then
										return
									else
										coroutine.resume(co, url)
									end
								end)
							end)
						end,
						webRoot = "${workspaceFolder}",
						userDataDir = "${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir",
					},
				}
			end

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

			Map("n", "<Leader>dp", dap.toggle_breakpoint, { desc = "setting break points" })
			Map("n", "<Leader>dc", dap.continue, { desc = "continue debugger" })
			Map("n", "<Leader>dt", dap_go.debug_test, { desc = "debug go test" })
			Map("n", "<Leader>dq", dap.close, { desc = "close debugger" })
			Map("n", "<Leader>di", dap.step_into, { desc = "step into code" })
			Map("n", "<Leader>do", dap.step_out, { desc = "step out of the code" })
			Map("n", "<Leader>ds", dap.step_over, { desc = "step over the code" })
		end,
	},
}
