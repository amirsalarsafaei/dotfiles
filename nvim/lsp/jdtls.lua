return {
	cmd = { "jdtls" },
	filetypes = { "java" },
	root_markers = {
		"build.gradle",
		"build.gradle.kts",
		"settings.gradle",
		"settings.gradle.kts",
		"pom.xml",
		".git",
	},
	settings = {
		java = {
			inlayHints = {
				parameterNames = { enabled = "all" },
			},
			signatureHelp = { enabled = true },
			completion = {
				favoriteStaticMembers = {
					"org.junit.Assert.*",
					"org.junit.jupiter.api.Assertions.*",
					"org.mockito.Mockito.*",
					"java.util.Objects.requireNonNull",
					"java.util.Objects.requireNonNullElse",
				},
				filteredTypes = {
					"com.sun.*",
					"io.micrometer.shaded.*",
					"java.awt.*",
					"jdk.*",
					"sun.*",
				},
			},
			sources = {
				organizeImports = {
					starThreshold = 9999,
					staticStarThreshold = 9999,
				},
			},
			codeGeneration = {
				toString = {
					template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
				},
				useBlocks = true,
			},
		},
	},
}
