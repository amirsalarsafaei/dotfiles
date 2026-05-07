{
  config,
  lib,
  pkgs,
  secrets,
  dotfilesRoot ? null,
  ...
}:
let
  gapClaudeCode = pkgs.symlinkJoin {
    name = "gap-claude-code";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --set ANTHROPIC_API_KEY "${secrets.gapgpt.apiKey}" \
        --set ANTHROPIC_BASE_URL "https://api.gapgpt.app/"
    '';
  };
in
{
  custom.neovim.source = "${config.home.homeDirectory}/personal/dotfiles/nvim";
  custom.dev.naviCheatsPath = lib.mkIf (dotfilesRoot != null) "${dotfilesRoot}/navi-cheats";
  custom.dev.extraPackages = [ gapClaudeCode ];
}
