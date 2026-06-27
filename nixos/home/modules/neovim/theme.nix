{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      plugins.mini = {
        enable = true;
        modules.base16 = { };
      };

      extraConfigLua = lib.mkOrder 100 ''
        local palette = _G.nvim_host.palette
        if palette ~= nil then
          require("mini.base16").setup({ palette = palette })

          local hl = function(group, opts)
            vim.api.nvim_set_hl(0, group, opts)
          end

          local function apply_slate_highlights()
            hl("Normal", { fg = palette.base05, bg = palette.base00 })
            hl("NormalFloat", { fg = palette.base06, bg = palette.base01 })
            hl("FloatBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("CursorLine", { bg = palette.base01 })
            hl("CursorLineNr", { fg = palette.base0A, bold = true })
            hl("LineNr", { fg = palette.base03 })
            hl("Visual", { bg = palette.base02 })
            hl("Search", { fg = palette.base00, bg = palette.base0A, bold = true })
            hl("IncSearch", { fg = palette.base00, bg = palette.base09, bold = true })
            hl("CurSearch", { fg = palette.base00, bg = palette.base09, bold = true })
            hl("MatchParen", { fg = palette.base0A, bg = palette.base02, bold = true })
            hl("Pmenu", { fg = palette.base06, bg = palette.base01 })
            hl("PmenuSel", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("PmenuThumb", { bg = palette.base0D })
            hl("WinSeparator", { fg = palette.base02 })
            hl("ColorColumn", { bg = palette.base01 })
            hl("SignColumn", { bg = palette.base00 })
            hl("DiagnosticError", { fg = palette.base08 })
            hl("DiagnosticWarn", { fg = palette.base0A })
            hl("DiagnosticInfo", { fg = palette.base0C })
            hl("DiagnosticHint", { fg = palette.base0B })
            hl("DiagnosticVirtualTextError", { fg = palette.base08, bg = palette.base01 })
            hl("DiagnosticVirtualTextWarn", { fg = palette.base0A, bg = palette.base01 })
            hl("DiagnosticVirtualTextInfo", { fg = palette.base0C, bg = palette.base01 })
            hl("DiagnosticVirtualTextHint", { fg = palette.base0B, bg = palette.base01 })
            hl("Comment", { fg = palette.base04, italic = true })
            hl("String", { fg = palette.base0B })
            hl("Character", { fg = palette.base0B })
            hl("Number", { fg = palette.base09 })
            hl("Boolean", { fg = palette.base09, bold = true })
            hl("Float", { fg = palette.base09 })
            hl("Function", { fg = palette.base0D, bold = true })
            hl("Identifier", { fg = palette.base06 })
            hl("Statement", { fg = palette.base09, bold = true })
            hl("Conditional", { fg = palette.base09, bold = true })
            hl("Repeat", { fg = palette.base09, bold = true })
            hl("Label", { fg = palette.base0A })
            hl("Operator", { fg = palette.base0C })
            hl("Keyword", { fg = palette.base09, bold = true })
            hl("Exception", { fg = palette.base08, bold = true })
            hl("PreProc", { fg = palette.base0A })
            hl("Include", { fg = palette.base0D })
            hl("Define", { fg = palette.base0A })
            hl("Macro", { fg = palette.base0A })
            hl("Type", { fg = palette.base0C, bold = true })
            hl("StorageClass", { fg = palette.base0A })
            hl("Structure", { fg = palette.base0C })
            hl("Typedef", { fg = palette.base0C })
            hl("Special", { fg = palette.base0D })
            hl("SpecialChar", { fg = palette.base0A })
            hl("Tag", { fg = palette.base0D })
            hl("Delimiter", { fg = palette.base04 })
            hl("@variable", { fg = palette.base06 })
            hl("@variable.builtin", { fg = palette.base09, bold = true })
            hl("@constant", { fg = palette.base09 })
            hl("@constant.builtin", { fg = palette.base09, bold = true })
            hl("@module", { fg = palette.base0A })
            hl("@string", { fg = palette.base0B })
            hl("@string.escape", { fg = palette.base0A })
            hl("@number", { fg = palette.base09 })
            hl("@boolean", { fg = palette.base09, bold = true })
            hl("@function", { fg = palette.base0D, bold = true })
            hl("@function.builtin", { fg = palette.base0C, bold = true })
            hl("@function.method", { fg = palette.base0D })
            hl("@constructor", { fg = palette.base0C, bold = true })
            hl("@keyword", { fg = palette.base09, bold = true })
            hl("@keyword.function", { fg = palette.base09, bold = true })
            hl("@keyword.return", { fg = palette.base08, bold = true })
            hl("@keyword.import", { fg = palette.base0D })
            hl("@operator", { fg = palette.base0C })
            hl("@type", { fg = palette.base0C, bold = true })
            hl("@type.builtin", { fg = palette.base0C, bold = true })
            hl("@property", { fg = palette.base0A })
            hl("@field", { fg = palette.base0A })
            hl("@punctuation.delimiter", { fg = palette.base04 })
            hl("@punctuation.bracket", { fg = palette.base04 })
            hl("@tag", { fg = palette.base0D })
            hl("@tag.attribute", { fg = palette.base0A })
            hl("@tag.delimiter", { fg = palette.base04 })
            hl("TelescopeNormal", { fg = palette.base06, bg = palette.base01 })
            hl("TelescopeBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("TelescopeTitle", { fg = palette.base0A, bold = true })
            hl("TelescopePromptNormal", { fg = palette.base07, bg = palette.base02 })
            hl("TelescopePromptBorder", { fg = palette.base0D, bg = palette.base02 })
            hl("TelescopePromptTitle", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("TelescopePromptPrefix", { fg = palette.base0A, bg = palette.base02 })
            hl("TelescopeSelection", { fg = palette.base07, bg = palette.base02, bold = true })
            hl("TelescopeMatching", { fg = palette.base0A, bold = true })
            hl("NvimTreeNormal", { fg = palette.base06, bg = palette.base01 })
            hl("NvimTreeWinSeparator", { fg = palette.base01, bg = palette.base01 })
            hl("NvimTreeFolderName", { fg = palette.base0D })
            hl("NvimTreeOpenedFolderName", { fg = palette.base0D, bold = true })
            hl("NvimTreeRootFolder", { fg = palette.base0A, bold = true })
            hl("NvimTreeIndentMarker", { fg = palette.base03 })
            hl("NvimTreeGitDirty", { fg = palette.base0A })
            hl("NvimTreeGitNew", { fg = palette.base0B })
            hl("NvimTreeGitDeleted", { fg = palette.base08 })
            hl("NvimTreeSpecialFile", { fg = palette.base0C, bold = true })
            hl("WhichKey", { fg = palette.base0A, bold = true })
            hl("WhichKeyGroup", { fg = palette.base0C })
            hl("WhichKeyDesc", { fg = palette.base06 })
            hl("WhichKeyBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("WhichKeyNormal", { bg = palette.base01 })
            hl("AlphaHeader", { fg = palette.base0D })
            hl("AlphaButtons", { fg = palette.base06 })
            hl("AlphaShortcut", { fg = palette.base0D, bold = true })
            hl("AlphaFooter", { fg = palette.base03 })
            hl("FlashLabel", { fg = palette.base00, bg = palette.base0A, bold = true })
            hl("FlashMatch", { fg = palette.base07, bg = palette.base02 })
            hl("FlashCurrent", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("TroubleNormal", { fg = palette.base06, bg = palette.base01 })
            hl("NotifyBackground", { bg = palette.base01 })
          end

          apply_slate_highlights()
          vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
            group = vim.api.nvim_create_augroup("SlateNixvimHighlights", { clear = true }),
            callback = apply_slate_highlights,
          })
        end
      '';
    };
  };
}
