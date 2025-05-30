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
			"theHamsta/nvim-dap-virtual-text",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")
			local dap_go = require("dap-go")
			local dap_js = require("dap-vscode-js")
			local dap_vt = require("nvim-dap-virtual-text")

			dap_vt.setup({})

			dap_go.setup({
				delve = {
					initialize_timeout_sec = 30,
					path = vim.fn.stdpath("data") .. "/mason/bin/dlv",
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

			dapui.setup({
				render = {
					max_type_length = 0,
				},
			})

			-- adding dap ui attachments
			dap.listeners.before.attach.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.launch.dapui_config = function()
				dapui.open()
			end

			vim.keymap.set("n", "<leader>rp", dap.toggle_breakpoint, { desc = "toggle debug break points", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>rbc", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "conditional break point", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>rbl", function()
				dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
			end, { desc = "logging break point", noremap = true, silent = true })

			vim.keymap.set("n", "<leader>rc", dap.continue, { desc = "continue debugger", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>rs", dap.close, { desc = "closes debugger", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>rl", dap.run_last, { desc = "runs last debug profile", noremap = true, silent = true })

			vim.keymap.set("n", "<leader>rj", dap.down, { desc = "go down in stack trace", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>rk", dap.up, { desc = "go up in stack trace", noremap = true, silent = true })

			vim.keymap.set("n", "<leader>rq", dapui.close, { desc = "close debugger ui", noremap = true, silent = true })

			vim.keymap.set("n", "<leader>ri", dap.step_into, { desc = "step into code", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>r0", dap.step_out, { desc = "step out of the code", noremap = true, silent = true })
			vim.keymap.set("n", "<leader>ro", dap.step_over, { desc = "step over the code", noremap = true, silent = true })

			vim.keymap.set("n", "<leader>rf", function()
				dapui.float_element("scopes", { enter = true })
			end, { noremap = true, silent = true })
		end,
	},
}
