return {
	{
		"nvim-treesitter/nvim-treesitter",
		event = { "BufReadPre", "BufNewFile" },
		build = ":TSUpdate",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		config = function()
			require("nvim-treesitter.configs").setup({
				highlight = { enable = true },
				indent = { enable = true },
				sync_install = false,
				auto_install = true,
				ensure_installed = {
					"go", "gomod", "gosum",
					"json", "jsonc",
					"javascript", "typescript", "tsx",
					"yaml", "toml",
					"html", "css", "scss",
					"markdown", "markdown_inline",
					"svelte", "vue",
					"graphql",
					"bash",
					"lua", "luadoc",
					"vim", "vimdoc",
					"dockerfile",
					"gitignore", "gitcommit", "diff",
					"query", "regex",
					"nix",
					"rust",
					"sql",
					"c", "cpp",
					"python",
					"kotlin", "java",
					"proto",
					"elixir",
				},
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "<C-space>",
						node_incremental = "<C-space>",
						scope_incremental = false,
						node_decremental = "<bs>",
					},
				},
				textobjects = {
					select = {
						enable = true,
						lookahead = true,
						keymaps = {
							["af"] = { query = "@function.outer", desc = "outer function" },
							["if"] = { query = "@function.inner", desc = "inner function" },
							["ac"] = { query = "@class.outer", desc = "outer class" },
							["ic"] = { query = "@class.inner", desc = "inner class" },
							["aa"] = { query = "@parameter.outer", desc = "outer argument" },
							["ia"] = { query = "@parameter.inner", desc = "inner argument" },
							["ai"] = { query = "@conditional.outer", desc = "outer conditional" },
							["ii"] = { query = "@conditional.inner", desc = "inner conditional" },
							["al"] = { query = "@loop.outer", desc = "outer loop" },
							["il"] = { query = "@loop.inner", desc = "inner loop" },
						},
					},
					move = {
						enable = true,
						set_jumps = true,
						goto_next_start = {
							["]f"] = { query = "@function.outer", desc = "Next function start" },
							["]c"] = { query = "@class.outer", desc = "Next class start" },
							["]a"] = { query = "@parameter.inner", desc = "Next argument" },
						},
						goto_next_end = {
							["]F"] = { query = "@function.outer", desc = "Next function end" },
							["]C"] = { query = "@class.outer", desc = "Next class end" },
						},
						goto_previous_start = {
							["[f"] = { query = "@function.outer", desc = "Prev function start" },
							["[c"] = { query = "@class.outer", desc = "Prev class start" },
							["[a"] = { query = "@parameter.inner", desc = "Prev argument" },
						},
						goto_previous_end = {
							["[F"] = { query = "@function.outer", desc = "Prev function end" },
							["[C"] = { query = "@class.outer", desc = "Prev class end" },
						},
					},
					swap = {
						enable = true,
						swap_next = {
							["<leader>a"] = { query = "@parameter.inner", desc = "Swap with next arg" },
						},
						swap_previous = {
							["<leader>A"] = { query = "@parameter.inner", desc = "Swap with prev arg" },
						},
					},
				},
			})
		end,
	},
	{
		"windwp/nvim-ts-autotag",
		event = "InsertEnter",
		opts = {},
	},
}
