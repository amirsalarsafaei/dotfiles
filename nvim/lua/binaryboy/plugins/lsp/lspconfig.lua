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
			{ "j-hui/fidget.nvim",                   opts = {} }, -- Use opts for simpler setup
		},
		config = function()
			-- Core requirements
			local lspconfig = require("lspconfig")
			local configs = require("lspconfig.configs")
			local util = require("lspconfig.util")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")
			local keymap = vim.keymap

			-- Fidget is configured via opts in the dependencies

			-----------------------------------------------------------
			-- LSP Keybindings
			-----------------------------------------------------------
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function(ev)
					local client = vim.lsp.get_client_by_id(ev.data.client_id)
					local bufnr = ev.buf

					-- Navigation
					keymap.set(
						"n",
						"gR",
						"<cmd>Telescope lsp_references include_declaration=false<CR>",
						{ buffer = bufnr, desc = "Show LSP references" }
					)
					keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Go to declaration" })
					keymap.set(
						"n",
						"gd",
						"<cmd>Telescope lsp_definitions<CR>",
						{ buffer = bufnr, desc = "Show LSP definitions" }
					)
					keymap.set(
						"n",
						"gi",
						"<cmd>Telescope lsp_implementations<CR>",
						{ buffer = bufnr, desc = "Show LSP implementations" }
					)
					keymap.set(
						"n",
						"gt",
						"<cmd>Telescope lsp_type_definitions<CR>",
						{ buffer = bufnr, desc = "Show LSP type definitions" }
					)

					-- Information
					keymap.set(
						"n",
						"K",
						vim.lsp.buf.hover,
						{ buffer = bufnr, desc = "Show documentation for what is under cursor" }
					)
					keymap.set("n", "gs", vim.lsp.buf.signature_help, { buffer = bufnr, desc = "Show signature help" })

					-- Code actions
					keymap.set(
						{ "n", "v" },
						"<leader>ca",
						vim.lsp.buf.code_action,
						{ buffer = bufnr, desc = "See available code actions" }
					)
					keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { buffer = bufnr, desc = "Smart rename" })

					-- Diagnostics
					keymap.set(
						"n",
						"<leader>D",
						"<cmd>Telescope diagnostics bufnr=0<CR>",
						{ buffer = bufnr, desc = "Show buffer diagnostics" }
					)
					keymap.set(
						"n",
						"<leader>d",
						vim.diagnostic.open_float,
						{ buffer = bufnr, desc = "Show line diagnostics" }
					)
					keymap.set(
						"n",
						"[d",
						vim.diagnostic.goto_prev,
						{ buffer = bufnr, desc = "Go to previous diagnostic" }
					)
					keymap.set("n", "]d", vim.diagnostic.goto_next, { buffer = bufnr, desc = "Go to next diagnostic" })

					-- Utility
					keymap.set("n", "<leader>rs", ":LspRestart<CR>", { buffer = bufnr, desc = "Restart LSP" })

					-- Inlay hints (Neovim 0.10+)
					if client and client:supports_method("textDocument/inlayHint") then
						-- Toggle inlay hints with <leader>ih
						keymap.set("n", "<leader>ih", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ buffer = bufnr }))
						end, { buffer = bufnr, desc = "Toggle inlay hints" })
					end
				end,
			})

			-----------------------------------------------------------
			-- LSP Diagnostics Configuration
			-----------------------------------------------------------
			-- Used to enable autocompletion (assign to every lsp server config)
			local capabilities = cmp_nvim_lsp.default_capabilities()

			-- Enable completions for all file operations
			capabilities.workspace = {
				fileOperations = {
					didCreate = true,
					didRename = true,
					didDelete = true,
					willCreate = true,
					willRename = true,
					willDelete = true,
				},
			}

			-- Diagnostic symbols in the sign column (gutter)
			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
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
				severity_sort = true,
				virtual_text = {
					prefix = "●", -- Could be '■', '▎', 'x'
					source = "if_many",
				},
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = signs.Error,
						[vim.diagnostic.severity.WARN] = signs.Warn,
						[vim.diagnostic.severity.HINT] = signs.Hint,
						[vim.diagnostic.severity.INFO] = signs.Info,
					},
				},
			})

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

				-- Enable inlay hints by default for supported servers (Neovim 0.10+)
				if vim.fn.has("nvim-0.10") == 1 then
					config.inlay_hints = config.inlay_hints or { enabled = true }
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
				filetypes = { "c", "cpp", "objc", "objcpp", "cuda" }, -- Explicitly exclude proto files
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
