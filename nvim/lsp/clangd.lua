return {
		cmd = { "clangd", "--background-index", "--clang-tidy" },
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- Explicitly exclude proto files
		init_options = {
			clangdFileStatus = true,
			usePlaceholders = true,
			completeUnimported = true,
			semanticHighlighting = true,
		},
}
