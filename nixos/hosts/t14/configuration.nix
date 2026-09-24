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
    # Work host configuration (work-claude variant, private skills)
    ../../modules/work.nix
    ../../private/hosts/t14
    # Logitech wireless mouse support (solaar: battery, DPI, buttons)
    ../../modules/logitech.nix
    ./virtualization.nix
  ];

  isLaptop = true;
  isWork = true;
  custom.dynamicPowerProfiles = true;

  # Fixes pixelated XWayland apps (e.g. burpsuite, a Java/Swing app that only
  # ever runs under XWayland — see home/modules/packages/security-tools.nix).
  # This panel (LG Display 0x06F7, 1920x1200) auto-scales to 1.50 in
  # Hyprland (`hyprctl monitors`); 96 * 1.5 = 144. Paired with
  # xwayland.force_zero_scaling in hyprland.nix.
  hyprland.xwaylandDpi = 144;

  hyprland.compactOutput = "eDP-1";

  services.thinkfan = {
    enable = true;
    sensors = [
      {
        type = "hwmon";
        query = "/sys/class/hwmon";
        name = "coretemp";
        indices = [ 1 ];
      }
    ];
    levels = [
      [
        0
        0
        42
      ]
      [
        1
        40
        50
      ]
      [
        3
        48
        56
      ]
      [
        5
        54
        62
      ]
      [
        7
        60
        72
      ]
      [
        "level full-speed"
        70
        32767
      ]
    ];
  };

  # Built-in fingerprint reader (Synaptics 06cb:00f9, BMKT match-on-chip). It's
  # natively supported by libfprint's open-source "synaptics" driver (no TOD/
  # proprietary blob needed) as of libfprint 1.94.10, which nixpkgs builds with
  # -Ddrivers=all. Enabling fprintd also flips every PAM service's fprintAuth
  # to true by default (login, sudo, hyprlock, greetd, ...) as a "sufficient"
  # step ahead of password, so it doesn't lock you out if no finger is
  # enrolled. After rebuilding, enroll with: fprintd-enroll
  services.fprintd.enable = true;

  services.netbird.enable = true;
  users.users.amirsalar.extraGroups = [ "netbird-wt0" ];

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
    netbird
    netbird-ui
  ];

  specialisation.low-power.configuration = {
    system.nixos.tags = [ "low-power" ];
    custom.powerProfile = "low-power";
  };

  specialisation.performance.configuration = {
    system.nixos.tags = [ "performance" ];
    custom.powerProfile = "performance";
  };

  system.stateVersion = "25.11";
}
