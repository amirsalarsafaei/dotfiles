return {
	cmd = { "protobuf-language-server" },
	filetypes = { "proto" },
	single_file_support = true,
	settings = {
		["additional-proto-dirs"] = { "third_party/proto", "src/proto" },
	},
}
