{ lib, ... }:
{
  # Stylix currently defines an Opencode TUI theme target, while the Home
  # Manager module version in this flake only exposes web/rules/tools options.
  # This shim keeps evaluation working until the upstream modules line up again.
  options.programs.opencode.tui = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Compatibility shim for Stylix's Opencode TUI target.";
  };

  # Stylix's Qt target expects Home Manager to expose `qt.kvantum`, but the
  # current module set in this flake has not caught up yet.
  options.qt.kvantum = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Compatibility shim for Stylix's Qt Kvantum target.";
  };
}
