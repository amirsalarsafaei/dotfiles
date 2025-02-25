return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPre", "BufNewFile" },
	build = ":TSUpdate",
	dependencies = {
		"windwp/nvim-ts-autotag",
	},
	config = function()
		-- import nvim-treesitter plugin
		local treesitter = require("nvim-treesitter.configs")

		-- configure treesitter
		treesitter.setup({ -- enable syntax highlighting
			highlight = {
				enable = true,
			},
			-- enable indentation
			indent = { enable = true },
			-- enable autotagging (w/ nvim-ts-autotag plugin)
			autotag = {
				enable = true,
			},
			sync_install = false,
			-- ensure these language parsers are installed
			ensure_installed = {
				"go",
				"json",
				"javascript",
				"typescript",
				"tsx",
				"yaml",
				"html",
				"css",
				"prisma",
				"markdown",
				"markdown_inline",
				"svelte",
				"graphql",
				"bash",
				"lua",
				"vim",
				"dockerfile",
				"gitignore",
				"query",
				"vimdoc",
				"nix",
				"gomod",
				"rust",
				"sql",
				"c",
				"python",
				"kotlin",
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "gn",
					node_incremental = "gn",
					scope_incremental = "gr",
					node_decremental = "gN",
				},
			},
			-- enable textobjects for better code manipulation
			textobjects = {
				select = {
					enable = true,
					lookahead = true, -- Automatically jump forward to textobj
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true, -- whether to set jumps in the jumplist
					goto_next_start = {
						["]m"] = "@function.outer",
						["]]"] = "@class.outer",
					},
					goto_next_end = {
						["]M"] = "@function.outer",
						["]["] = "@class.outer",
					},
					goto_previous_start = {
						["[m"] = "@function.outer",
						["[["] = "@class.outer",
					},
					goto_previous_end = {
						["[M"] = "@function.outer",
						["[]"] = "@class.outer",
					},
				},
			},
			-- enable rainbow parentheses
			rainbow = {
				enable = true,
				extended_mode = true, -- Highlight also non-parentheses delimiters
				max_file_lines = nil, -- Do not enable for files with more than n lines
			},
			-- enable context-based commentstring
			context_commentstring = {
				enable = true,
				enable_autocmd = false,
			},
		})
	end,
}
