return {
	"hrsh7th/nvim-cmp",
	event = { "InsertEnter", "CmdlineEnter" }, -- Load for both insert and cmdline
	dependencies = {
		"hrsh7th/cmp-buffer",                   -- source for text in buffer
		"hrsh7th/cmp-path",                     -- source for file system paths
		"hrsh7th/cmp-cmdline",                  -- source for cmdline completion
		"hrsh7th/cmp-nvim-lua",                 -- source for neovim Lua API
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*", -- follow latest release
			build = "make install_jsregexp",
			dependencies = {
				"rafamadriz/friendly-snippets", -- useful snippets
			},
		},
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"onsails/lspkind.nvim",   -- vs-code like pictograms
		"Snikimonkd/cmp-go-pkgs",
		"hrsh7th/cmp-nvim-lsp-signature-help",
		"roobert/tailwindcss-colorizer-cmp.nvim", -- tailwind colors in completion
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local lspkind = require("lspkind")

		-- Setup tailwindcss colorizer if available
		local has_tailwind_colorizer, tailwind_colorizer_cmp = pcall(require, "tailwindcss-colorizer-cmp")

		-- Variable to track signature help state
		local signature_help_enabled = true

		-- Function to toggle signature help
		local function toggle_signature_help()
			signature_help_enabled = not signature_help_enabled
			local sources = cmp.get_config().sources

			-- Rebuild sources list
			local new_sources = {}
			for _, source in ipairs(sources) do
				if source.name ~= "nvim_lsp_signature_help" then
					table.insert(new_sources, source)
				end
			end

			-- Add signature help if enabled
			if signature_help_enabled then
				table.insert(new_sources, { name = "nvim_lsp_signature_help" })
			end

			cmp.setup.buffer({ sources = new_sources })
			vim.notify("Signature help " .. (signature_help_enabled and "enabled" or "disabled"))
		end

		-- Load vscode style snippets from installed plugins (e.g. friendly-snippets)
		require("luasnip.loaders.from_vscode").lazy_load()

		-- Enable LuaSnip history
		luasnip.config.setup({
			history = true,
			updateevents = "TextChanged,TextChangedI",
			enable_autosnippets = true,
		})

		-- Terminal completion configuration
		cmp.setup.filetype("toggleterm", {
			sources = {
				{ name = "buffer" },
				{ name = "path" },
			},
		})

		-- Command line completion setup
		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "path" },
				{ name = "cmdline" },
				{ name = "nvim_lua" },
			}),
			formatting = {
				fields = { "abbr", "kind" },
			},
		})

		-- Search completion setup
		cmp.setup.cmdline({ "/", "?" }, {
			mapping = cmp.mapping.preset.cmdline(),
			sources = {
				{ name = "buffer" },
			},
		})

		-- Main completion setup
		cmp.setup({
			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},
			window = {
				completion = cmp.config.window.bordered({
					winhighlight = "Normal:CmpNormal,FloatBorder:CmpBorder,CursorLine:PmenuSel,Search:None",
					scrollbar = true,
					col_offset = -3,
					side_padding = 0,
				}),
				documentation = cmp.config.window.bordered({
					winhighlight = "Normal:CmpDocNormal,FloatBorder:CmpDocBorder,CursorLine:CmpDocSel,Search:None",
				}),
			},
			sorting = {
				priority_weight = 2.5, -- Give more weight to priority
				comparators = {
					-- Prioritize exact matches first
					cmp.config.compare.exact,
					cmp.config.compare.score,
					cmp.config.compare.offset,
					-- Prioritize recently used items more
					cmp.config.compare.recently_used,
					-- Prioritize items from current buffer more
					cmp.config.compare.locality,
					cmp.config.compare.kind,
					cmp.config.compare.sort_text,
					cmp.config.compare.length,
					cmp.config.compare.order,
				},
			},
			snippet = { -- configure how nvim-cmp interacts with snippet engine
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-s>"] = cmp.mapping.complete_common_string(),
				["<A-s>"] = function()
					toggle_signature_help()
				end, -- Toggle signature help
				["<C-k>"] = cmp.mapping.scroll_docs(-4),
				["<C-j>"] = cmp.mapping.scroll_docs(4),
				["<A-c>"] = cmp.mapping.complete(), -- show completion suggestions
				["<C-e>"] = cmp.mapping.abort(), -- close completion window
				["<CR>"] = cmp.mapping.confirm({ select = false }),
				-- Tab mapping
				["<C-n>"] = function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif luasnip.expand_or_jumpable() then
						luasnip.expand_or_jump()
					else
						fallback()
					end
				end,
				["<C-p>"] = function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif luasnip.jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end,
			}),
			-- sources for autocompletion
			sources = cmp.config.sources({
				{ name = "nvim_lsp",                priority = 8 },
				{ name = "nvim_lsp_signature_help", priority = 7 },
				{ name = "luasnip",                 priority = 7 }, -- snippets
				{ name = "nvim_lua",                priority = 6 }, -- neovim lua API
				{ name = "buffer",                  priority = 5, keyword_length = 4 }, -- text within current buffer
				{ name = "go_pkgs",                 priority = 5 },
				{ name = "path",                    priority = 4 }, -- file system paths
			}),
			enabled = function()
				-- Disable completion in comments
				local context = require("cmp.config.context")
				-- Keep command mode completion enabled when cursor is in a comment
				if vim.api.nvim_get_mode().mode == "c" then
					return true
				else
					return not context.in_treesitter_capture("comment") and not context.in_syntax_group("Comment")
				end
			end,

			-- Configure lspkind for vs-code like pictograms in completion menu
			formatting = {
				format = function(entry, vim_item)
					-- Add indicator for selected item
					local item_selected = (entry.completion_item.data or {}).item_selected or false
					if item_selected then
						vim_item.abbr = "→ " .. vim_item.abbr
					end

					-- Basic formatting with lspkind
					local formatted = lspkind.cmp_format({
						maxwidth = 50,
						mode = "symbol",
						with_text = true,
						menu = {
							nvim_lsp = "[LSP]",
							nvim_lua = "[Lua]",
							luasnip = "[Snip]",
							buffer = "[Buf]",
							path = "[Path]",
							go_pkgs = "[Go]",
							cmdline = "[Cmd]",
							nvim_lsp_signature_help = "[Sig]",
						},
						before = function(entry_item, vim_item_inner)
							-- Show source name in the menu
							vim_item_inner.menu = vim_item_inner.menu or ""

							-- Get source name
							local source_name = entry_item.source.name
							if source_name == "nvim_lsp" then
								vim_item_inner.dup = 0 -- Remove duplicates from LSP
							end

							return vim_item_inner
						end,
					})(entry, vim_item)

					-- Add tailwind colors if available
					if has_tailwind_colorizer then
						formatted = tailwind_colorizer_cmp.formatter(entry, formatted)
					end

					return formatted
				end,
			},
			matching = { disallow_symbol_nonprefix_matching = false }, -- to use . and / in urls
			experimental = {
				ghost_text = { hl_group = "CmpGhostText" },           -- Show ghost text
				native_menu = false,
			},
			view = {
				entries = { name = "custom", selection_order = "near_cursor" },
			},
		})
	end,
}
