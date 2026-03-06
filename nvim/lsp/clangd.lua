return {
		cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
		"--query-driver=/nix/store/*/bin/xtensa-*,/nix/store/*/bin/*-gcc,/nix/store/*/bin/*-g++",
	},
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- Explicitly exclude proto files
		init_options = {
			clangdFileStatus = true,
			usePlaceholders = true,
			completeUnimported = true,
			semanticHighlighting = true,
		},
}
