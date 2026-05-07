{
  config,
  inputs,
  secrets,
  dotfilesRoot ? null,
  lib,
  pkgs,
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
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.spicetify-nix.homeManagerModules.default
    ../modules/programs/terminal
    ../modules/programs/desktop
    ../modules/programs/development/workstation.nix
    ../modules/packages/desktop-all.nix
    ../modules/services
    ../modules/systemd
    ../modules/scripts
  ];

  sops = {
    secrets.ssh_config = {
      path = "${config.home.homeDirectory}/.ssh/config.d/sops";
    };
  };

  custom.dev.naviCheatsPath = lib.mkIf (dotfilesRoot != null) "${dotfilesRoot}/navi-cheats";
  custom.dev.extraPackages = [ gapClaudeCode ];
}
