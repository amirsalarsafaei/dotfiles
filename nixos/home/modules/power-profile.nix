{ lib, ... }:
{
  options.custom.powerProfile = lib.mkOption {
    type = lib.types.enum [
      "normal"
      "low-power"
    ];
    default = "normal";
    description = ''
      Power profile passed down from the NixOS host (via
      home-manager.sharedModules). Per-user modules — e.g. swaync vs
      dunst — switch on this so the same dotfiles work for both
      specialisations without per-host duplication.
    '';
  };
}
