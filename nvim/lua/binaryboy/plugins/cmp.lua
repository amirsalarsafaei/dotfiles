return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		{
			"L3MON4D3/LuaSnip",
			-- follow latest release.
			version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
			-- install jsregexp (optional!).
			build = "make install_jsregexp",
		},
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- vs-code like pictograms
		"Snikimonkd/cmp-go-pkgs",
		"hrsh7th/cmp-nvim-lsp-signature-help",
	},
	config = function()
		local cmp = require("cmp")

		local luasnip = require("luasnip")

		local lspkind = require("lspkind")

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

		-- loads vscode style snippets from installed plugins (e.g. friendly-snippets)
		require("luasnip.loaders.from_vscode").lazy_load()

		-- Terminal completion configuration
		cmp.setup.filetype("toggleterm", {
			sources = {
				{ name = "buffer" },
				{ name = "path" },
			},
		})

		cmp.setup({
			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},
			sorting = {
				priority_weight = 2,
				comparators = {
					cmp.config.compare.offset,
					cmp.config.compare.exact,
					cmp.config.compare.score,
					cmp.config.compare.recently_used,
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
				{ name = "nvim_lsp", priority = 8 },
				{ name = "nvim_lsp_signature_help" },
				{ name = "luasnip", priority = 7 }, -- snippets
				{ name = "buffer", priority = 7, keyword_length = 4 }, -- text within current buffer
				{ name = "go_pkgs", priority = 5 },
				{ name = "path", priority = 4 }, -- file system paths
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

			-- configure lspkind for vs-code like pictograms in completion menu
			--
			formatting = {
				format = lspkind.cmp_format({
					maxwidth = 50,
					mode = "symbol",
					with_text = true,
					menu = {
						go_pkgs = "[pkgs]",
					},
				}),
			},
			matching = { disallow_symbol_nonprefix_matching = false }, -- to use . and / in urls
		})
	end,
}
