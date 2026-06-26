return {
	{
		"towolf/vim-helm",
		ft = "helm",
		init = function()
			vim.filetype.add({
				pattern = {
					[".*/templates/.*%.ya?ml"] = "helm",
					[".*/templates/.*%.tpl"] = "helm",
					[".*/helmfile%.ya?ml"] = "helm",
					[".*%.ya?ml%.gotmpl"] = "helm",
				},
			})
		end,
	},
}
