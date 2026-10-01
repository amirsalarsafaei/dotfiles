{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.browserMcp;
  browserMcp = pkgs.callPackage ../../../../pkgs/browser-mcp { };
in
{
  options.custom.browserMcp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the shared browser MCP broker as a user service, so every Claude Code session can drive the same browser tab through the Browser MCP extension instead of one session owning port 9009.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = browserMcp;
      description = "The Browser MCP build providing the broker daemon and the broker-aware MCP server.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ browserMcp ];

    systemd.user.services.browser-mcp-broker = {
      Unit = {
        Description = "Shared browser MCP broker for the Browser MCP extension";
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
      Service = {
        ExecStart = "${browserMcp}/bin/browser-mcp-broker";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
