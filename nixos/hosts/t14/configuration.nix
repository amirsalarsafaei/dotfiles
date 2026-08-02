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

  # Built-in fingerprint reader (Synaptics 06cb:00f9, BMKT match-on-chip). It's
  # natively supported by libfprint's open-source "synaptics" driver (no TOD/
  # proprietary blob needed) as of libfprint 1.94.10, which nixpkgs builds with
  # -Ddrivers=all. Enabling fprintd also flips every PAM service's fprintAuth
  # to true by default (login, sudo, hyprlock, greetd, ...) as a "sufficient"
  # step ahead of password, so it doesn't lock you out if no finger is
  # enrolled. After rebuilding, enroll with: fprintd-enroll
  services.fprintd.enable = true;

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
    s-tui
    stress-ng
    powertop
    linuxPackages_latest.cpupower
    linuxPackages_latest.turbostat
  ];

  specialisation.low-power.configuration = {
    system.nixos.tags = [ "low-power" ];
    custom.powerProfile = "low-power";
  };

  system.stateVersion = "25.11";
}
