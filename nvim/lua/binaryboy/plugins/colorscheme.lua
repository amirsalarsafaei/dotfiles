-- Reads base16 palette from nvim-host.lua (exported by NixOS theme module)
-- and applies it via mini.base16, then sets plugin-specific overrides.

local host = require("binaryboy.core.hostconfig")
local p = host.palette

return {
  "echasnovski/mini.base16",
  priority = 1000,
  lazy = false,
  cond = p.base00 ~= nil,
  config = function()
    vim.o.termguicolors = true

    require("mini.base16").setup({ palette = p })

    local hl = function(group, opts)
      vim.api.nvim_set_hl(0, group, opts)
    end

    -- telescope
    hl("TelescopeNormal", { fg = p.base06, bg = p.base01 })
    hl("TelescopeBorder", { fg = p.base03, bg = p.base01 })
    hl("TelescopeTitle", { fg = p.base0D, bold = true })
    hl("TelescopePromptNormal", { fg = p.base06, bg = p.base02 })
    hl("TelescopePromptBorder", { fg = p.base03, bg = p.base02 })
    hl("TelescopePromptTitle", { fg = p.base0D, bg = p.base02, bold = true })
    hl("TelescopePromptPrefix", { fg = p.base0D, bg = p.base02 })
    hl("TelescopeSelection", { bg = p.base03 })
    hl("TelescopeMatching", { fg = p.base0D, bold = true })

    -- nvim-tree
    hl("NvimTreeNormal", { fg = p.base06, bg = p.base01 })
    hl("NvimTreeWinSeparator", { fg = p.base01, bg = p.base01 })
    hl("NvimTreeFolderName", { fg = p.base0D })
    hl("NvimTreeOpenedFolderName", { fg = p.base0D, bold = true })
    hl("NvimTreeRootFolder", { fg = p.base0D, bold = true })
    hl("NvimTreeIndentMarker", { fg = p.base03 })
    hl("NvimTreeGitDirty", { fg = p.base0A })
    hl("NvimTreeGitNew", { fg = p.base0B })
    hl("NvimTreeGitDeleted", { fg = p.base08 })
    hl("NvimTreeSpecialFile", { fg = p.base0C })

    -- which-key
    hl("WhichKey", { fg = p.base0D })
    hl("WhichKeyGroup", { fg = p.base0C })
    hl("WhichKeyDesc", { fg = p.base06 })
    hl("WhichKeyBorder", { fg = p.base03, bg = p.base01 })
    hl("WhichKeyNormal", { bg = p.base01 })

    -- alpha
    hl("AlphaHeader", { fg = p.base0D })
    hl("AlphaButtons", { fg = p.base06 })
    hl("AlphaShortcut", { fg = p.base0D, bold = true })
    hl("AlphaFooter", { fg = p.base03 })

    -- flash
    hl("FlashLabel", { fg = p.base00, bg = p.base0D, bold = true })
    hl("FlashMatch", { fg = p.base06, bg = p.base03 })
    hl("FlashCurrent", { fg = p.base06, bg = p.base03, bold = true })

    -- trouble
    hl("TroubleNormal", { fg = p.base06, bg = p.base01 })

    -- notify / snacks
    hl("NotifyBackground", { bg = p.base01 })

    pcall(function()
      require("avante_lib").load()
    end)
  end,
}
