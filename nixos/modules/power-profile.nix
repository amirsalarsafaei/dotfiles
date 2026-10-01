{ config, lib, ... }:
let
  cfg = config.custom.powerProfile;
  isLowPower = cfg == "low-power";
  isPerformance = cfg == "performance";

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
      "performance" profile at boot.
    '';
  };

  options.custom.dynamicPowerProfiles = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Use power-profiles-daemon instead of automatic TLP AC/battery profiles.";
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

    (lib.mkIf (config.isLaptop && config.custom.dynamicPowerProfiles && isPerformance) {
      systemd.services.power-profile-default = {
        description = "Select the power-profiles-daemon performance profile";
        after = [ "power-profiles-daemon.service" ];
        requires = [ "power-profiles-daemon.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl"} set performance";
        };
      };
    })
  ];
}
