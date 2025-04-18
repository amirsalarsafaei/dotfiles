return {
	{
		"folke/neodev.nvim",
		ft = "lua", -- only load on lua files
		opts = {
			library = {
				plugins = { "neotest" },
				types = true,
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			{ "antosha417/nvim-lsp-file-operations", config = true },
			"nanotee/sqls.nvim",
			"j-hui/fidget.nvim",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local configs = require("lspconfig.configs")
			local util = require("lspconfig.util")
			local mason_lspconfig = require("mason-lspconfig")
			require("fidget").setup()

			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			local keymap = vim.keymap -- for conciseness

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function(ev)
					-- Buffer local mappings.
					-- See `:help vim.lsp.*` for documentation on any of the below functions
					local opts = { buffer = ev.buf, silent = true }

					-- set keybinds
					opts.desc = "Show LSP references"
					keymap.set("n", "gR", "<cmd>Telescope lsp_references include_declaration=false<CR>", opts) -- show definition, references

					opts.desc = "Go to declaration"
					keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

					opts.desc = "Show signature help"
					keymap.set("n", "gs", vim.lsp.buf.signature_help, opts) -- show lsp definitions

					opts.desc = "Show LSP definitions"
					keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

					opts.desc = "Show LSP implementations"
					keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", opts) -- show lsp implementations

					opts.desc = "Show LSP type definitions"
					keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", opts) -- show lsp type definitions

					opts.desc = "See available code actions"
					keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

					opts.desc = "Smart rename"
					keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

					opts.desc = "Show buffer diagnostics"
					keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file

					opts.desc = "Show line diagnostics"
					keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

					opts.desc = "Go to previous diagnostic"
					keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer

					opts.desc = "Go to next diagnostic"
					keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer

					opts.desc = "Show documentation for what is under cursor"
					keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

					opts.desc = "Restart LSP"
					keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
				end,
			})

			-- used to enable autocompletion (assign to every lsp server config)
			local capabilities = cmp_nvim_lsp.default_capabilities()
			vim.diagnostic.config({
				update_in_insert = true,
				float = {
					focusable = false,
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			})

			-- Change the Diagnostic symbols in the sign column (gutter)
			-- (not in youtube nvim video)
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			-- Common root patterns for all LSP servers
			local common_root_patterns = {
				-- Version Control
				".git",
				".gitignore",
				-- Package Managers
				"package.json",
				"yarn.lock",
				"pnpm-lock.yaml",
				"bun.lockb",
				"composer.json",
				"Cargo.toml",
				"go.mod",
				"requirements.txt",
				"pyproject.toml",
				"Gemfile",
				-- Build Tools
				"Makefile",
				"CMakeLists.txt",
				"build.gradle",
				"pom.xml",
				-- Documentation
				"README.md",
				"README",
				-- Project Config
				".editorconfig",
				".prettierrc",
				"tsconfig.json",
				-- Environment
				".env",
				".nvmrc",
				-- IDE/Editor
				".vscode",
				".idea",
			}

			mason_lspconfig.setup_handlers({
				-- default handler for installed servers
				function(server_name)
					lspconfig[server_name].setup({
						capabilities = capabilities,
						root_dir = lspconfig.util.root_pattern(unpack(common_root_patterns)),
					})
				end,
				["gopls"] = function()
					lspconfig.gopls.setup({
						capabilities = capabilities,
						root_dir = lspconfig.util.root_pattern(unpack(common_root_patterns)),
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
					})
				end,
				["lua_ls"] = function()
					-- configure lua server (with special settings)
					lspconfig["lua_ls"].setup({
						capabilities = capabilities,
						settings = {
							Lua = {
								-- make the language server recognize "vim" global
								diagnostics = {
									globals = { "vim" },
								},
								completion = {
									callSnippet = "Replace",
								},
								runtime = {
									version = "LuaJIT",
								},
							},
						},
					})
				end,
				["eslint"] = function()
					lspconfig.eslint.setup({
						root_dir = require("lspconfig").util.root_pattern(
							-- ESLint specific files
							"eslint.config.js",
							".eslintrc.js",
							".eslintrc.json",
							".eslintrc",
							".eslintrc.cjs",
							".eslintrc.yaml",
							".eslintrc.yml",
							-- Common project root files
							".gitignore",
							".git",
							"package.json",
							"yarn.lock",
							"pnpm-lock.yaml",
							"bun.lockb",
							"Makefile",
							"README.md",
							"README"
						),
					})
				end,
				["elixirls"] = function()
					lspconfig["elixirls"].setup({
						capabilities = capabilities,
						cmd = { vim.fn.stdpath("data") .. "/mason/bin/elixir-ls" },
					})
				end,
				["lexical"] = function()
					lspconfig["lexical"].setup({
						capabilities = capabilities,
						cmd = { vim.fn.stdpath("data") .. "/mason/bin/lexical" },
					})
				end,
				["sqls"] = function()
					lspconfig["sqls"].setup({
						capabilities = capabilities,
						on_attach = function(client, bufn)
							require("sqls").on_attach(client, bufn)
						end,
					})
				end,
				["yamlls"] = function()
					lspconfig.yamlls.setup({
						capabilities = capabilities,
						settings = {
							yaml = {
								validate = true,
								schemas = {
									kubernetes = { "k8s**.yaml", "kube*/*.yaml" },
								},
							},
						},
					})
				end,
				["buf_ls"] = function()
					-- don't attach buf lsp
				end,
			})

			lspconfig.clangd.setup({
				capabilities = capabilities,
				cmd = { "clangd", "--background-index", "--clang-tidy" },
				init_options = {
					-- You can add clangd-specific initialization options here
					clangdFileStatus = true,
					usePlaceholders = true,
					completeUnimported = true,
					semanticHighlighting = true,
				},
			})
			configs["protobuf-language-server"] = {
				default_config = {
					cmd = { vim.env.GOBIN .. "/protobuf-language-server" },
					filetypes = { "proto" },
					root_fir = util.root_pattern(".git"),
					single_file_support = true,
					settings = {
						["additional-proto-dirs"] = { "third_party/proto", "src/proto" },
					},
				},
			}
			lspconfig["protobuf-language-server"].setup({
				capabilities = capabilities,
			})
			lspconfig.nixd.setup({
				capabilities = capabilities,
				settings = {
					nixpkgs = {
						expr = "import <nixpkgs> { }",
					},
					formatting = {
						command = { "nixfmt" },
					},
					options = {
						nixos = {
							expr = '(builtins.getFlake ("git+file://" + toString ./.)).nixosConfigurations.k-on.options',
						},
						home_manager = {
							expr = '(builtins.getFlake ("git+file://" + toString ./.)).homeConfigurations."ruixi@k-on".options',
						},
					},
				},
			})
		end,
	},
}
