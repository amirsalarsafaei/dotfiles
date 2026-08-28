{
  config,
  pkgs,
  lib,
  ...
}:

let
  goHassAgent = pkgs.go-hass-agent;

  # Registration (HA server URL + long-lived token) is one-time and persisted
  # to ~/.config/go-hass-agent/preferences.toml ([agent] registered = true),
  # so it's only run when that flag is missing. MQTT settings are re-applied
  # on every start so drift from the sops secret / homeNetwork config self-heals.
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

    # Secrets/keyring
    lxqt.lxqt-openssh-askpass
    gnome-keyring
    libsecret
    libgnome-keyring
    gcr

    # Nvidia/graphics
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

    # Networking
    networkmanager-fortisslvpn

    # Desktop
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
    ../../modules/home-network.nix
  ];

  isLaptop = true;

  # SSIDs and mqtt broker live in hosts/common/default.nix.
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
    # Add to secrets/secrets.yaml via `sops secrets/secrets.yaml`:
    #   mqtt-credentials: |
    #     MQTT_USER=mqtt
    #     MQTT_PASS=<password>
    #     HA_SERVER=http://homeassistant.local:8123
    #     HA_TOKEN=<long-lived access token>
    mode = "0400";
  };

  home-manager.users.amirsalar = {
    custom = {
      claudeCode = {
        enableWork = true;
        # Local model bridge (`local-claude` -> LiteLLM -> llama-swap).
        # The server side lives in ./local-llm.nix.
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

      # Auto-launch ROG Control Center (tray companion to asusd). Bound to
      # graphical-session.target (started by uwsm) rather than a hyprland target,
      # since Hyprland runs with systemd.enable off — same approach as clipse.
      rog-control-center = {
        Unit = {
          Description = "ROG Control Center";
          PartOf = [ "graphical-session.target" ];
          Wants = [ "waybar.service" ];
          After = [
            "graphical-session.target"
            "waybar.service"
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

  # ASUS/ROG
  services.asusd = {
    enable = true;
  };
  services.supergfxd.enable = true;
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  # Boot
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

  # Graphics
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];
  hardware.nvidia = nvidia;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Audio
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

  # Apps
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

  # services.llama-swap is configured in ./local-llm.nix (CUDA llama.cpp +
  # the Qwen3.6-APEX coding model wired to Claude Code).

  services.open-webui = {
    enable = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      OFFLINE_MODE = "true";
    };
  };

  # face unlock (Windows Hello-style)
  # IMPORTANT: control = "sufficient" means a face match grants auth,
  # but a failure/timeout falls back to password. Never use "required"
  # (the upstream default) — a failed face match would lock you out.
  # After rebuild you MUST enroll a face before it can match:
  #   sudo howdy -U amirsalar add
  # Test it without risk via: sudo -k; sudo -i
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

    # G14-specific: rip out Nvidia entirely (TLP, heavy services, and
    # swaync→dunst fallback are handled by modules/power-profile.nix).
    services.xserver.videoDrivers = lib.mkForce [ "amdgpu" ];
    hardware.nvidia.prime.sync.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia-container-toolkit.enable = lib.mkForce false;
    boot.blacklistedKernelModules = blacklistNvidia;
    boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (m: "blacklist ${m}") blacklistNvidia;

    # Disable nvidia-gpu exporter since nvidia is disabled
    services.prometheus.exporters.nvidia-gpu.enable = lib.mkForce false;

    hyprland.monitorConfig = "eDP-1,2880x1800@60,0x0,1.6";
  };

  hardware.nvidia-container-toolkit.enable = true;

  system.stateVersion = "25.05";
  # programs.wireshark.enable = true; # temporarily disabled: upstream hash mismatch
}
