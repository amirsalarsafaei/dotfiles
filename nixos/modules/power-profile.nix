{ config, lib, ... }:
let
  cfg = config.custom.powerProfile;
  hardening = import ../home/modules/systemd/lib.nix { inherit lib; };
  isLowPower = cfg == "low-power";
  isPerformance = cfg == "performance";
  batteryProfile = config.custom.batteryPowerProfile;
  acProfile =
    {
      normal = "balanced";
      low-power = "power-saver";
      performance = "performance";
    }
    .${cfg};
  selectsProfile =
    config.isLaptop && config.custom.dynamicPowerProfiles && (isPerformance || batteryProfile != null);

  acSettings = {
    CPU_SCALING_GOVERNOR = "performance";
    CPU_ENERGY_PERF_POLICY = "performance";
    CPU_BOOST = 1;
    PLATFORM_PROFILE = "performance";
  };
  batSettings =
    if isPerformance then
      acSettings
    else
      {
        CPU_SCALING_GOVERNOR = "powersave";
        CPU_ENERGY_PERF_POLICY = "power";
        CPU_BOOST = 0;
        PLATFORM_PROFILE = "low-power";
      };

  tlpSettings = {
    CPU_SCALING_GOVERNOR_ON_AC = acSettings.CPU_SCALING_GOVERNOR;
    CPU_SCALING_GOVERNOR_ON_BAT = batSettings.CPU_SCALING_GOVERNOR;
    CPU_ENERGY_PERF_POLICY_ON_AC = acSettings.CPU_ENERGY_PERF_POLICY;
    CPU_ENERGY_PERF_POLICY_ON_BAT = batSettings.CPU_ENERGY_PERF_POLICY;
    CPU_BOOST_ON_AC = acSettings.CPU_BOOST;
    CPU_BOOST_ON_BAT = batSettings.CPU_BOOST;
    PLATFORM_PROFILE_ON_AC = acSettings.PLATFORM_PROFILE;
    PLATFORM_PROFILE_ON_BAT = batSettings.PLATFORM_PROFILE;
    RUNTIME_PM_ON_AC = "auto";
    RUNTIME_PM_ON_BAT = "auto";
    PCIE_ASPM_ON_BAT = if isPerformance then "performance" else "powersupersave";
  };
in
{
  options.custom.powerProfile = lib.mkOption {
    type = lib.types.enum [
      "normal"
      "low-power"
      "performance"
    ];
    default = "normal";
    description = ''
      Boot-time system profile. "low-power" disables heavy services
      (ollama, open-webui, grafana, prometheus), switches laptops to TLP
      with battery-favouring tunings, and tells home-manager to fall back
      to dunst instead of swaync for notifications. "performance" pins
      laptops to the AC-power TLP tunings (performance governor/EPP,
      boost on, performance platform profile) even on battery, or, with
      dynamicPowerProfiles, selects the power-profiles-daemon
      "performance" profile at boot, or on AC power only when
      batteryPowerProfile is set.
    '';
  };

  options.custom.dynamicPowerProfiles = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Use power-profiles-daemon instead of automatic TLP AC/battery profiles.";
  };

  options.custom.batteryPowerProfile = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "power-saver"
        "balanced"
        "performance"
      ]
    );
    default = null;
    description = ''
      power-profiles-daemon profile selected at boot on battery and
      whenever a laptop with dynamicPowerProfiles unplugs. Plugging in
      selects the profile matching powerProfile again. A manual choice
      holds until the next power source change. null leaves the profile
      alone on power source changes.
    '';
  };

  config = lib.mkMerge [
    {
      home-manager.sharedModules = [
        { custom.powerProfile = cfg; }
      ];
    }

    (lib.mkIf isLowPower {
      services = {
        grafana.enable = lib.mkForce false;
        prometheus.enable = lib.mkForce false;
        ollama.enable = lib.mkForce false;
        open-webui.enable = lib.mkForce false;
      };
    })

    (lib.mkIf config.isLaptop {
      services.power-profiles-daemon.enable = config.custom.dynamicPowerProfiles;
      services.tlp = {
        enable = !config.custom.dynamicPowerProfiles;
        settings = tlpSettings;
      };
    })

    (lib.mkIf selectsProfile {
      systemd.services.power-profile-default = {
        description = "Select the power-profiles-daemon profile for the power source";
        after = [ "power-profiles-daemon.service" ];
        requires = [ "power-profiles-daemon.service" ];
        wantedBy = [ "graphical.target" ];
        serviceConfig = lib.mkMerge [
          hardening.system
          {
            Type = "oneshot";
            RestrictAddressFamilies = [ "AF_UNIX" ];
          }
        ];
        script = ''
          profile=${acProfile}
          ${lib.optionalString (batteryProfile != null) ''
            profile=${batteryProfile}
            for supply in /sys/class/power_supply/*; do
              read -r type < "$supply/type" || continue
              if [ "$type" != Mains ]; then
                continue
              fi
              read -r online < "$supply/online" || continue
              if [ "$online" = 1 ]; then
                profile=${acProfile}
              fi
            done
          ''}
          exec ${lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl"} set "$profile"
        '';
      };

      services.udev.extraRules = lib.mkIf (batteryProfile != null) ''
        SUBSYSTEM=="power_supply", ACTION=="change", ATTR{type}=="Mains", RUN+="${lib.getExe' config.systemd.package "systemctl"} --no-block restart power-profile-default.service"
      '';
    })
  ];
}
