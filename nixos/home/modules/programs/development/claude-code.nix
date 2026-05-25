{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.custom.claudeCode;

  mkVariant =
    {
      name,
      configDir,
      extraWrapperArgs ? [ ],
    }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.claude-code}/bin/claude $out/bin/${name} \
        --set CLAUDE_CONFIG_DIR "${configDir}" \
        ${lib.concatStringsSep " " extraWrapperArgs}
    '';

  gapClaude = mkVariant {
    name = "gap-claude";
    configDir = "${config.home.homeDirectory}/.config/gap-claude";
    extraWrapperArgs = [
      ''--set ANTHROPIC_API_KEY "${secrets.gapgpt.apiKey or ""}"''
      ''--set ANTHROPIC_BASE_URL "https://api.gapgpt.app/"''
    ];
  };

  claudeWork = mkVariant {
    name = "claude-work";
    configDir = "${config.home.homeDirectory}/.config/claude-work";
  };
in
{
  options.custom.claudeCode = {
    enable = lib.mkEnableOption "Install claude-code and the gap-claude wrapper";
    enableWork = lib.mkEnableOption "Install the claude-work variant (work-host only)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = [
        pkgs.claude-code
        gapClaude
      ];
    })
    (lib.mkIf cfg.enableWork {
      home.packages = [ claudeWork ];
    })
  ];
}
