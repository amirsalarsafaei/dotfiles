{
  pkgs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan (placeholder — see that file).
    ./hardware-configuration.nix
    # LUKS-on-GPT disk layout (nix-community/disko)
    ./disko.nix
    # Laptop configuration
    ../../modules/laptop.nix
    # Work host configuration (claude-work variant, private skills)
    ../../modules/work.nix
    ./virtualization.nix
  ];

  isLaptop = true;
  isWork = true;

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    zsh
    brightnessctl
    xdg-utils
    iwd
    alsa-utils
    wireplumber
    kdePackages.qtmultimedia
    libfido2
  ];

  specialisation.low-power.configuration = {
    system.nixos.tags = [ "low-power" ];
    custom.powerProfile = "low-power";
  };

  system.stateVersion = "25.11";
}
