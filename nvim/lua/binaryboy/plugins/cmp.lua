return {
	"saghen/blink.cmp",
	version = "1.*",
	lazy = false, -- lazy loading handled internally
	dependencies = {
		"rafamadriz/friendly-snippets", -- useful snippets
		"folke/lazydev.nvim", -- better lua completion for neovim config
	},
	opts = {
		-- Enables keymaps, completions and signature help when true
		enabled = function()
			return true
		end,

		-- Keymap configuration
		keymap = {
			preset = "default",
			-- Custom keymaps based on old nvim-cmp configuration
			["<C-s>"] = { "show", "fallback" }, -- Show completion (closest to complete_common_string)
			["<A-s>"] = {
				function(cmp)
					-- Toggle signature help
					if require("blink.cmp.signature").is_open() then
						cmp.hide_signature()
					else
						cmp.show_signature()
					end
				end
			},
			["<C-k>"] = { "scroll_documentation_up", "fallback" },
			["<C-j>"] = { "scroll_documentation_down", "fallback" },
			["<A-c>"] = { "show", "fallback" }, -- Show completion suggestions
			["<C-e>"] = { "cancel", "fallback" }, -- Close completion window
			["<Tab>"] = { "accept", "fallback" }, -- Confirm selection (more ergonomic than Enter)
			-- Navigation with snippet support
			["<C-n>"] = {
				function(cmp)
					if cmp.snippet_active() then
						return cmp.snippet_forward()
					else
						return cmp.select_next()
					end
				end,
				"fallback"
			},
			["<C-p>"] = {
				function(cmp)
					if cmp.snippet_active() then
						return cmp.snippet_backward()
					else
						return cmp.select_prev()
					end
				end,
				"fallback"
			},
		},

		-- Appearance configuration
		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		-- Sources configuration
		sources = {
			default = { "lsp", "path", "buffer", "snippets" },
			per_filetype = {
				toggleterm = { "buffer", "path" },
			},
		},

		-- Snippets configuration
		snippets = {
			expand = function(snippet)
				vim.snippet.expand(snippet)
			end,
			active = function(filter)
				return vim.snippet.active(filter)
			end,
			jump = function(direction)
				vim.snippet.jump(direction)
			end,
		},

		-- Completion configuration
		completion = {
			keyword = {
				range = "prefix",
			},
			trigger = {
				prefetch_on_insert = true,
				show_in_snippet = true,
				show_on_backspace = false,
				show_on_backspace_in_keyword = false,
				show_on_backspace_after_accept = true,
				show_on_backspace_after_insert_enter = true,
				show_on_keyword = true,
				show_on_trigger_character = true,
				show_on_insert = false,
				show_on_blocked_trigger_characters = { "\n", "\t" },
				show_on_accept_on_trigger_character = true,
				show_on_insert_on_trigger_character = true,
				show_on_x_blocked_trigger_characters = { "'", '"', "(" },
			},
			list = {
				max_items = 200,
				selection = {
					preselect = true,
					auto_insert = true,
				},
				cycle = {
					from_bottom = true,
					from_top = true,
				},
			},
			accept = {
				dot_repeat = true,
				create_undo_point = true,
				resolve_timeout_ms = 100,
				auto_brackets = {
					enabled = true,
					default_brackets = { "(", ")" },
					override_brackets_for_filetypes = {},
					kind_resolution = {
						enabled = true,
						blocked_filetypes = { "typescriptreact", "javascriptreact", "vue" },
					},
					semantic_token_resolution = {
						enabled = true,
						blocked_filetypes = { "java" },
						timeout_ms = 400,
					},
				},
			},
			menu = {
				enabled = true,
				min_width = 15,
				max_height = 10,
				border = "rounded",
				winblend = 0,
				winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
				scrolloff = 2,
				scrollbar = true,
				direction_priority = { "s", "n" },
				auto_show = true,
				draw = {
					align_to = "label",
					padding = 1,
					gap = 1,
					cursorline_priority = 10000,
					treesitter = { "lsp" },
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source_name" } },
				},
			},
			documentation = {
				auto_show = false,
				auto_show_delay_ms = 500,
				update_delay_ms = 50,
				treesitter_highlighting = true,
				window = {
					min_width = 10,
					max_width = 80,
					max_height = 20,
					border = "rounded",
					winblend = 0,
					winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
					scrollbar = true,
					direction_priority = {
						menu_north = { "e", "w", "n", "s" },
						menu_south = { "e", "w", "s", "n" },
					},
				},
			},
			ghost_text = {
				enabled = false,
				show_with_selection = true,
				show_without_selection = false,
				show_with_menu = true,
				show_without_menu = true,
			},
		},

		-- Signature help configuration
		signature = {
			enabled = false,
			trigger = {
				enabled = true,
				show_on_keyword = false,
				blocked_trigger_characters = {},
				blocked_retrigger_characters = {},
				show_on_trigger_character = true,
				show_on_insert = false,
				show_on_insert_on_trigger_character = true,
			},
			window = {
				min_width = 1,
				max_width = 100,
				max_height = 10,
				border = "rounded",
				winblend = 0,
				winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
				scrollbar = false,
				direction_priority = { "n", "s" },
				treesitter_highlighting = true,
				show_documentation = true,
			},
		},

		-- Fuzzy matching configuration
		fuzzy = {
			implementation = "prefer_rust_with_warning",
			max_typos = function(keyword)
				return math.floor(#keyword / 4)
			end,
			use_frecency = true,
			use_proximity = true,
			use_unsafe_no_lock = false,
			sorts = { "score", "sort_text" },
			prebuilt_binaries = {
				download = true,
				ignore_version_mismatch = false,
				force_version = nil,
				force_system_triple = nil,
				extra_curl_args = {},
				proxy = {
					from_env = true,
					url = nil,
				},
			},
		},
	},
	config = function(_, opts)
		-- Setup blink.cmp
		local blink_cmp = require("blink.cmp")
		blink_cmp.setup(opts)


		-- Setup custom highlight groups
		vim.api.nvim_set_hl(0, "BlinkCmpMenu", { link = "Pmenu" })
		vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { link = "FloatBorder" })
		vim.api.nvim_set_hl(0, "BlinkCmpMenuSelection", { link = "PmenuSel" })
		vim.api.nvim_set_hl(0, "BlinkCmpDoc", { link = "NormalFloat" })
		vim.api.nvim_set_hl(0, "BlinkCmpDocBorder", { link = "FloatBorder" })
		vim.api.nvim_set_hl(0, "BlinkCmpDocCursorLine", { link = "Visual" })
		vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelp", { link = "NormalFloat" })
		vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", { link = "FloatBorder" })

		-- Disable completion in comments
	end,
}
