return {
	settings = {
		yaml = {
			validate = true,
			schemas = {
				kubernetes = { "k8s**.yaml", "kube*/*.yaml" },
			},
		},
	},
}
