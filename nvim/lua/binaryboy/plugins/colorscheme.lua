return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  lazy = true,
  opts = {
    flavour = "mocha",
    transparent_background = false,
    term_colors = true,
    dim_inactive = {
      enabled = false,
    },
    styles = {
      comments = {},
      conditionals = {},
    },
    color_overrides = {
      mocha = {
        rosewater = "#a7b4c9",
        flamingo = "#8ea4bf",
        pink = "#76b3d6",
        mauve = "#5d8fd8",
        red = "#d16d6d",
        maroon = "#bf616a",
        peach = "#d49a6a",
        yellow = "#d6b57a",
        green = "#8fbf7f",
        teal = "#6fbdb3",
        sky = "#76cce0",
        sapphire = "#5fb3d9",
        blue = "#6ea8ff",
        lavender = "#9bbcff",
        text = "#c7d0e0",
        subtext1 = "#a9b4c7",
        subtext0 = "#8f9bb0",
        overlay2 = "#7a869b",
        overlay1 = "#677388",
        overlay0 = "#566176",
        surface2 = "#3a465d",
        surface1 = "#2f3a4e",
        surface0 = "#253044",
        base = "#131922",
        mantle = "#0f141c",
        crust = "#0b1017",
      },
    },
    custom_highlights = function(colors)
      return {
        Comment = { fg = colors.overlay1, italic = false },
        Function = { fg = colors.blue },
        Keyword = { fg = colors.sapphire, italic = false },
        Type = { fg = colors.sky },
        String = { fg = colors.green },
      }
    end,
    integrations = {
      alpha = true,
      blink_cmp = true,
      diffview = true,
      fidget = true,
      gitsigns = true,
      harpoon = true,
      indent_blankline = { enabled = true },
      lsp_trouble = true,
      mason = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      nvimtree = true,
      telescope = { enabled = true },
      treesitter = true,
      which_key = true,
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin-nvim")

    pcall(function()
      require("avante_lib").load()
    end)
  end,
}
