{
  config,
  pkgs,
  lib,
  ...
}:

let
  goHassAgent = pkgs.go-hass-agent;

  goHassAgentStart = pkgs.writeShellScript "go-hass-agent-start" ''
    set -eu

    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/go-hass-agent"
    prefs_file="$config_dir/preferences.toml"

    set -a
    . ${lib.escapeShellArg config.sops.secrets.mqtt-credentials.path}
    set +a

    if [ ! -f "$prefs_file" ] || ! ${pkgs.gnugrep}/bin/grep -qx 'registered = true' "$prefs_file"; then
      ${goHassAgent}/bin/go-hass-agent register --server="$HA_SERVER" --token="$HA_TOKEN"
    fi

    ${goHassAgent}/bin/go-hass-agent config \
      --mqtt-enabled \
      --mqtt-server="tcp://${config.custom.homeNetwork.mqtt.host}:${toString config.custom.homeNetwork.mqtt.port}" \
      --mqtt-user="''${MQTT_USER:-}" \
      --mqtt-password="''${MQTT_PASS:-}" \
      --mqtt-topic-prefix="go-hass-agent"

    exec ${goHassAgent}/bin/go-hass-agent run
  '';

  rogControlCenterStart = pkgs.writeShellScript "rog-control-center-start" ''
    ${lib.getExe' pkgs.glib "gdbus"} wait --session --timeout 30 org.kde.StatusNotifierWatcher
    exec ${pkgs.asusctl}/bin/rog-control-center
  '';

  nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    dynamicBoost.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    prime = {
      sync.enable = true;
      amdgpuBusId = "PCI:101:0:0";
      nvidiaBusId = "PCI:100:0:0";
    };
  };

  systemPkgs = with pkgs; [
    git
    vim
    wget
    zsh
    brightnessctl
    xdg-utils
    qemu
    iwd
    alsa-utils
    wireplumber
    mesa-demos

    lxqt.lxqt-openssh-askpass
    gnome-keyring
    libsecret
    libgnome-keyring
    gcr_4

    nvidia-vaapi-driver
    libva
    libvdpau
    libva-vdpau-driver
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
    egl-wayland
    libglvnd
    mesa
    libva-utils

    networkmanager-fortisslvpn

    kdePackages.qtmultimedia
    esptool
    protonup-qt
    steam-run
  ];

  blacklistNvidia = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
in
{
  imports = [
    ./hardware-configuration.nix
    ./local-llm.nix
    ../../modules/laptop.nix
  ];

  isLaptop = true;

  custom.homeNetwork = {
    enable = true;
    mqtt = {
      enable = true;
      deviceName = "G14";
      credentialsFile = config.sops.secrets.mqtt-credentials.path;
    };
  };

  sops.secrets.mqtt-credentials = {
    owner = "amirsalar";
    mode = "0400";
  };

  home-manager.users.amirsalar = {
    custom = {
      claudeCode = {
        enableWork = true;
        enableLocal = true;
        plugins.local."clangd-lsp@claude-plugins-official" = true;
      };
      opencode.enableLocal = true;
    };

    home.packages = [ goHassAgent ];

    systemd.user.services = {
      go-hass-agent = {
        Unit = {
          Description = "Go Hass Agent";
          PartOf = [ "graphical-session.target" ];
          After = [
            "network-online.target"
            "graphical-session.target"
          ];
        };
        Service = {
          ExecStart = "${goHassAgentStart}";
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      rog-control-center = {
        Unit = {
          Description = "ROG Control Center";
          PartOf = [ "graphical-session.target" ];
          Wants = [ "quickshell.service" ];
          After = [
            "graphical-session.target"
            "quickshell.service"
          ];
        };
        Service = {
          ExecStart = "${rogControlCenterStart}";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  services.asusd = {
    enable = true;
  };
  services.supergfxd.enable = true;
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.extraEntries."arch.conf" = ''
      title   Arch Linux
      linux   /vmlinuz-linux
      initrd  /initramfs-linux.img
      options root=UUID=cf2d005d-e51b-45b2-a5eb-c4fcdc2d3c4c rw
    '';
    kernelPackages = pkgs.linuxPackages_latest;
  };

  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
  hardware.nvidia = nvidia;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  programs.firefox.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  services.flatpak.enable = true;
  systemd.services.flatpak-flathub = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${lib.getExe pkgs.flatpak} remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  services.llama-cpp = {
    enable = true;
    settings = {
      host = "127.0.0.1";
      port = 5888;
    };
    openFirewall = false;
    package = pkgs.llama-cpp;
  };

  services.open-webui = {
    enable = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      OFFLINE_MODE = "true";
    };
  };

  services.howdy = {
    enable = true;
    control = "sufficient";
    settings.video = {
      device_path = "/dev/video2";
      certainty = 3.5;
      timeout = 4;
      dark_threshold = 50;
    };
  };

  environment.systemPackages = systemPkgs;

  specialisation.on-the-go.configuration = {
    system.nixos.tags = [ "on-the-go" ];
    hardware.nvidia.prime = {
      offload.enable = lib.mkForce true;
      offload.enableOffloadCmd = lib.mkForce true;
      sync.enable = lib.mkForce false;
    };
    environment.sessionVariables = {
      AQ_DRM_DEVICES = "/dev/dri/card2:/dev/dri/card1";
      WLR_DRM_DEVICES = "/dev/dri/card2:/dev/dri/card1";
    };
    services.grafana.enable = lib.mkForce false;
    services.prometheus.enable = lib.mkForce false;
  };

  specialisation.low-power.configuration = {
    system.nixos.tags = [ "low-power" ];

    custom.powerProfile = "low-power";

    services.xserver.videoDrivers = lib.mkForce [ "amdgpu" ];
    hardware.nvidia.prime.sync.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    boot.blacklistedKernelModules = blacklistNvidia;
    boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (m: "blacklist ${m}") blacklistNvidia;

    services.prometheus.exporters.nvidia-gpu.enable = lib.mkForce false;

    hyprland.monitorConfig = "eDP-1,2880x1800@120,0x0,1.6";
  };

  hardware.nvidia-container-toolkit.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl --machine=amirsalar@ --user start oled-power-sync.service"
  '';

  system.stateVersion = "25.05";
}
