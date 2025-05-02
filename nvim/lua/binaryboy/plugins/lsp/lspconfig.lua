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
			-- Core requirements
			local lspconfig = require("lspconfig")
			local configs = require("lspconfig.configs")
			local util = require("lspconfig.util")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")
			local keymap = vim.keymap

			-- Setup fidget for LSP progress display
			require("fidget").setup()

			-----------------------------------------------------------
			-- LSP Keybindings
			-----------------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function(ev)
					-- Navigation
					keymap.set(
						"n",
						"gR",
						"<cmd>Telescope lsp_references include_declaration=false<CR>",
						{ buffer = ev.buf, desc = "Show LSP references" }
					)
					keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = ev.buf, desc = "Go to declaration" })
					keymap.set(
						"n",
						"gd",
						"<cmd>Telescope lsp_definitions<CR>",
						{ buffer = ev.buf, desc = "Show LSP definitions" }
					)
					keymap.set(
						"n",
						"gi",
						"<cmd>Telescope lsp_implementations<CR>",
						{ buffer = ev.buf, desc = "Show LSP implementations" }
					)
					keymap.set(
						"n",
						"gt",
						"<cmd>Telescope lsp_type_definitions<CR>",
						{ buffer = ev.buf, desc = "Show LSP type definitions" }
					)

					-- Information
					keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						{ buffer = ev.buf, desc = "Show documentation for what is under cursor" }
					)
					keymap.set("n", "gs", vim.lsp.buf.signature_help, { buffer = ev.buf, desc = "Show signature help" })

					-- Code actions
					keymap.set(
						{ "n", "v" },
						"<leader>ca",
						vim.lsp.buf.code_action,
						{ buffer = ev.buf, desc = "See available code actions" }
					)
					keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = ev.buf, desc = "Smart rename" })

					-- Diagnostics
					keymap.set(
						"n",
						"<leader>D",
						"<cmd>Telescope diagnostics bufnr=0<CR>",
						{ buffer = ev.buf, desc = "Show buffer diagnostics" }
					)
					keymap.set(
						"n",
						"<leader>d",
						vim.diagnostic.open_float,
						{ buffer = ev.buf, desc = "Show line diagnostics" }
					)
					keymap.set(
						"n",
						"[d",
						vim.diagnostic.goto_prev,
						{ buffer = ev.buf, desc = "Go to previous diagnostic" }
					)
					keymap.set("n", "]d", vim.diagnostic.goto_next, { buffer = ev.buf, desc = "Go to next diagnostic" })

					-- Utility
					keymap.set("n", "<leader>rs", ":LspRestart<CR>", { buffer = ev.buf, desc = "Restart LSP" })
				end,
			})

			-----------------------------------------------------------
			-- LSP Diagnostics Configuration
			-----------------------------------------------------------
			-- Used to enable autocompletion (assign to every lsp server config)
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

			-- Diagnostic symbols in the sign column (gutter)
			-- (not in youtube nvim video)
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			-- Common root patterns for project detection
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

			-- Helper function to setup servers with common configuration
			local function setup_server(server, config)
				config = config or {}
				config.capabilities = config.capabilities or capabilities

				-- Apply root_dir if not explicitly set
				if not config.root_dir and not server.root_dir then
					config.root_dir = lspconfig.util.root_pattern(unpack(common_root_patterns))
				end

				lspconfig[server].setup(config)
			end

			-----------------------------------------------------------
			-- Language Server Configurations
			-----------------------------------------------------------
			-- Go
			setup_server("gopls", {
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

			-- Lua
			setup_server("lua_ls", {
				settings = {
					Lua = {
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

			-- ESLint
			setup_server("eslint", {
				root_dir = lspconfig.util.root_pattern(
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

			-- Elixir
			setup_server("elixirls")

			-- OCaml
			setup_server("lexical")

			-- SQL
			setup_server("sqls", {
				on_attach = function(client, bufn)
					require("sqls").on_attach(client, bufn)
				end,
			})

			-- YAML
			setup_server("yamlls", {
				settings = {
					yaml = {
						validate = true,
						schemas = {
							kubernetes = { "k8s**.yaml", "kube*/*.yaml" },
						},
					},
				},
			})

			-- TypeScript/JavaScript
			setup_server("ts_ls")

			-- Python
			setup_server("pyright")

			-- Rust
			setup_server("rust_analyzer")

			-- C/C++
			setup_server("clangd", {
				cmd = { "clangd", "--background-index", "--clang-tidy" },
				init_options = {
					clangdFileStatus = true,
					usePlaceholders = true,
					completeUnimported = true,
					semanticHighlighting = true,
				},
			})

			-- Protobuf
			configs["protobuf-language-server"] = {
				default_config = {
					cmd = { vim.env.GOBIN .. "/protobuf-language-server" },
					filetypes = { "proto" },
					root_dir = util.root_pattern(".git"),
					single_file_support = true,
					settings = {
						["additional-proto-dirs"] = { "third_party/proto", "src/proto" },
					},
				},
			}
			lspconfig["protobuf-language-server"].setup({
				capabilities = capabilities,
			})

			-- Nix
			setup_server("nixd", {
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
