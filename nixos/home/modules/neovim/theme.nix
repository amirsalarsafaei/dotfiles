{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  p = helpers.palette;
in
{
  config = lib.mkIf (cfg.enable && p != null) {
    programs.nixvim = {
      plugins.mini = {
        enable = true;
        modules.base16.palette = lib.genAttrs helpers.paletteKeys (key: p.${key});
      };

      highlightOverride = {
        Normal = { fg = p.base05; bg = p.base00; };
        NormalFloat = { fg = p.base06; bg = p.base01; };
        FloatBorder = { fg = p.base0D; bg = p.base01; };
        CursorLine = { bg = p.base01; };
        CursorLineNr = { fg = p.base0A; bold = true; };
        LineNr = { fg = p.base03; };
        Visual = { bg = p.base02; };
        Search = { fg = p.base00; bg = p.base0A; bold = true; };
        IncSearch = { fg = p.base00; bg = p.base09; bold = true; };
        CurSearch = { fg = p.base00; bg = p.base09; bold = true; };
        MatchParen = { fg = p.base0A; bg = p.base02; bold = true; };
        Pmenu = { fg = p.base06; bg = p.base01; };
        PmenuSel = { fg = p.base00; bg = p.base0D; bold = true; };
        PmenuThumb = { bg = p.base0D; };
        WinSeparator = { fg = p.base02; };
        ColorColumn = { bg = p.base01; };
        SignColumn = { bg = p.base00; };
        DiagnosticError = { fg = p.base08; };
        DiagnosticWarn = { fg = p.base0A; };
        DiagnosticInfo = { fg = p.base0C; };
        DiagnosticHint = { fg = p.base0B; };
        DiagnosticVirtualTextError = { fg = p.base08; bg = p.base01; };
        DiagnosticVirtualTextWarn = { fg = p.base0A; bg = p.base01; };
        DiagnosticVirtualTextInfo = { fg = p.base0C; bg = p.base01; };
        DiagnosticVirtualTextHint = { fg = p.base0B; bg = p.base01; };
        Comment = { fg = p.base04; italic = true; };
        String = { fg = p.base0B; };
        Character = { fg = p.base0B; };
        Number = { fg = p.base09; };
        Boolean = { fg = p.base09; bold = true; };
        Float = { fg = p.base09; };
        Function = { fg = p.base0D; bold = true; };
        Identifier = { fg = p.base06; };
        Statement = { fg = p.base09; bold = true; };
        Conditional = { fg = p.base09; bold = true; };
        Repeat = { fg = p.base09; bold = true; };
        Label = { fg = p.base0A; };
        Operator = { fg = p.base0C; };
        Keyword = { fg = p.base09; bold = true; };
        Exception = { fg = p.base08; bold = true; };
        PreProc = { fg = p.base0A; };
        Include = { fg = p.base0D; };
        Define = { fg = p.base0A; };
        Macro = { fg = p.base0A; };
        Type = { fg = p.base0C; bold = true; };
        StorageClass = { fg = p.base0A; };
        Structure = { fg = p.base0C; };
        Typedef = { fg = p.base0C; };
        Special = { fg = p.base0D; };
        SpecialChar = { fg = p.base0A; };
        Tag = { fg = p.base0D; };
        Delimiter = { fg = p.base04; };
        "@variable" = { fg = p.base06; };
        "@variable.builtin" = { fg = p.base09; bold = true; };
        "@constant" = { fg = p.base09; };
        "@constant.builtin" = { fg = p.base09; bold = true; };
        "@module" = { fg = p.base0A; };
        "@string" = { fg = p.base0B; };
        "@string.escape" = { fg = p.base0A; };
        "@number" = { fg = p.base09; };
        "@boolean" = { fg = p.base09; bold = true; };
        "@function" = { fg = p.base0D; bold = true; };
        "@function.builtin" = { fg = p.base0C; bold = true; };
        "@function.method" = { fg = p.base0D; };
        "@constructor" = { fg = p.base0C; bold = true; };
        "@keyword" = { fg = p.base09; bold = true; };
        "@keyword.function" = { fg = p.base09; bold = true; };
        "@keyword.return" = { fg = p.base08; bold = true; };
        "@keyword.import" = { fg = p.base0D; };
        "@operator" = { fg = p.base0C; };
        "@type" = { fg = p.base0C; bold = true; };
        "@type.builtin" = { fg = p.base0C; bold = true; };
        "@property" = { fg = p.base0A; };
        "@field" = { fg = p.base0A; };
        "@punctuation.delimiter" = { fg = p.base04; };
        "@punctuation.bracket" = { fg = p.base04; };
        "@tag" = { fg = p.base0D; };
        "@tag.attribute" = { fg = p.base0A; };
        "@tag.delimiter" = { fg = p.base04; };
        TelescopeNormal = { fg = p.base06; bg = p.base01; };
        TelescopeBorder = { fg = p.base0D; bg = p.base01; };
        TelescopeTitle = { fg = p.base0A; bold = true; };
        TelescopePromptNormal = { fg = p.base07; bg = p.base02; };
        TelescopePromptBorder = { fg = p.base0D; bg = p.base02; };
        TelescopePromptTitle = { fg = p.base00; bg = p.base0D; bold = true; };
        TelescopePromptPrefix = { fg = p.base0A; bg = p.base02; };
        TelescopeSelection = { fg = p.base07; bg = p.base02; bold = true; };
        TelescopeMatching = { fg = p.base0A; bold = true; };
        NvimTreeNormal = { fg = p.base06; bg = p.base01; };
        NvimTreeWinSeparator = { fg = p.base01; bg = p.base01; };
        NvimTreeFolderName = { fg = p.base0D; };
        NvimTreeOpenedFolderName = { fg = p.base0D; bold = true; };
        NvimTreeRootFolder = { fg = p.base0A; bold = true; };
        NvimTreeIndentMarker = { fg = p.base03; };
        NvimTreeGitDirty = { fg = p.base0A; };
        NvimTreeGitNew = { fg = p.base0B; };
        NvimTreeGitDeleted = { fg = p.base08; };
        NvimTreeSpecialFile = { fg = p.base0C; bold = true; };
        WhichKey = { fg = p.base0A; bold = true; };
        WhichKeyGroup = { fg = p.base0C; };
        WhichKeyDesc = { fg = p.base06; };
        WhichKeyBorder = { fg = p.base0D; bg = p.base01; };
        WhichKeyNormal = { bg = p.base01; };
        AlphaHeader = { fg = p.base0D; };
        AlphaButtons = { fg = p.base06; };
        AlphaShortcut = { fg = p.base0D; bold = true; };
        AlphaFooter = { fg = p.base03; };
        FlashLabel = { fg = p.base00; bg = p.base0A; bold = true; };
        FlashMatch = { fg = p.base07; bg = p.base02; };
        FlashCurrent = { fg = p.base00; bg = p.base0D; bold = true; };
        TroubleNormal = { fg = p.base06; bg = p.base01; };
        NotifyBackground = { bg = p.base01; };
      };
    };
  };
}
