{ config, lib, ... }:
let
  cfg = config.custom.powerProfile;
  isLowPower = cfg == "low-power";

  tlpSettings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 0;
    PLATFORM_PROFILE_ON_AC = "performance";
    PLATFORM_PROFILE_ON_BAT = "low-power";
    RUNTIME_PM_ON_AC = "auto";
    RUNTIME_PM_ON_BAT = "auto";
    PCIE_ASPM_ON_BAT = "powersupersave";
  };
in
{
  options.custom.powerProfile = lib.mkOption {
    type = lib.types.enum [
      "normal"
      "low-power"
    ];
    default = "normal";
    description = ''
      Boot-time system profile. "low-power" disables heavy services
      (ollama, open-webui, grafana, prometheus), switches laptops to TLP
      with battery-favouring tunings, and tells home-manager to fall back
      to dunst instead of swaync for notifications.
    '';
  };

  config = lib.mkMerge [
    {
      home-manager.sharedModules = [
        { custom.powerProfile = cfg; }
      ];
    }

    (lib.mkIf isLowPower {
      services.grafana.enable = lib.mkForce false;
      services.prometheus.enable = lib.mkForce false;
      services.ollama.enable = lib.mkForce false;
      services.open-webui.enable = lib.mkForce false;
    })

    (lib.mkIf (isLowPower && config.isLaptop) {
      services.power-profiles-daemon.enable = lib.mkForce false;
      services.tlp = {
        enable = true;
        settings = tlpSettings;
      };
    })
  ];
}
