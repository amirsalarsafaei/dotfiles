{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/laptop.nix
    ../../modules/work.nix
    ../../private/hosts/t14
    ../../modules/logitech.nix
    ./virtualization.nix
  ];

  isLaptop = true;
  isWork = true;
  custom.dynamicPowerProfiles = true;
  custom.powerProfile = "performance";

  hyprland.xwaylandDpi = 144;

  hyprland.compactOutput = "eDP-1";

  systemd.services.rapl-power-limit = {
    description = "Raise the package power limit on AC in the performance profile";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
    };
    script = ''
      limit=/sys/class/powercap/intel-rapl-mmio:0/constraint_0_power_limit_uw
      target=28000000
      saved=""
      [ -e "$limit" ] || exit 0
      while :; do
        current=$(cat "$limit")
        if [ "$(cat /sys/class/power_supply/AC/online)" = 1 ] && [ "$(cat /sys/firmware/acpi/platform_profile)" = performance ]; then
          if [ "$current" -lt "$target" ]; then
            saved=$current
            echo "$target" > "$limit" || true
          fi
        elif [ -n "$saved" ]; then
          if [ "$current" = "$target" ]; then
            echo "$saved" > "$limit" || true
          fi
          saved=""
        fi
        sleep 10
      done
    '';
  };

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

  services.fprintd.enable = true;

  services.netbird.enable = true;
  users.users.amirsalar.extraGroups = [ "netbird-wt0" ];

  virtualisation.docker.enableOnBoot = false;
  custom.localMonitoring.enable = false;
  services.printing.browsed.enable = false;

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

  system.stateVersion = "25.11";
}
