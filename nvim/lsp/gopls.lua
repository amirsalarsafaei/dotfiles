return {
	settings = {
		gopls = {
			codelenses = {
				gc_details = true,
				generate = true,
				regenerate_cgo = true,
				run_govulncheck = true,
				test = true,
				tidy = true,
				upgrade_dependency = true,
			},
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
			analyses = {
				nilness = true,
				unusedparams = true,
				unusedwrite = true,
				useany = true,
				yield = true,
				waitgroup = true,
			},
			staticcheck = true,
			directoryFilters = {
				"-.git",
				"-.vscode",
				"-.idea",
				"-.vscode-test",
				"-node_modules",
				"-.nvim",
			},
			semanticTokens = true,
		},
	},
}
