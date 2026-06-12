{
  config,
  pkgs,
  lib,
  ...
}:

let
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
    # Add to secrets/secrets.yaml via `sops secrets/secrets.yaml`:
    #   mqtt-credentials: |
    #     MQTT_USER=mqtt
    #     MQTT_PASS=<password>
    mode = "0400";
  };

  home-manager.users.amirsalar.custom.claudeCode.enableWork = true;
  # Local model bridge (`local-claude` -> claude-code-router -> llama-swap).
  # The server side lives in ./local-llm.nix.
  home-manager.users.amirsalar.custom.claudeCode.enableLocal = true;

  # ASUS/ROG
  services.asusd = {
    enable = true;
  };
  services.supergfxd.enable = true;
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  # Auto-launch ROG Control Center (tray companion to asusd). Bound to
  # graphical-session.target (started by uwsm) rather than a hyprland target,
  # since Hyprland runs with systemd.enable off — same approach as clipse.
  home-manager.users.amirsalar.systemd.user.services.rog-control-center = {
    Unit = {
      Description = "ROG Control Center";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.asusctl}/bin/rog-control-center";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  services.llama-cpp = {
    enable = true;
    host = "127.0.0.1";
    port = 5888;
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

    hyprland.monitorConfig = "eDP-1,2880x1800@60,0x0,1.6";
  };

  hardware.nvidia-container-toolkit.enable = true;

  system.stateVersion = "25.05";
  # programs.wireshark.enable = true; # temporarily disabled: upstream hash mismatch
}
