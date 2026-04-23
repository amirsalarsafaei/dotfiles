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
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    prime = {
      sync.enable = true;
      amdgpuBusId = "PCI:101:0:0";
      nvidiaBusId = "PCI:100:0:0";
    };
  };

  ollamaModels = [
    "VladimirGav/gemma4-26b-16GB-VRAM"
    "gpt-oss:20b"
    "qwen3-coder:30b"
    "qwen3.6:35b-a3b-coding-nvfp4"
    "gemma4:26b"
    "n27/gemma-4-26B-A4B-it-UD-Q4_K_M-32k"
  ];

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
    seahorse
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
    sddm-astronaut
    esptool
  ];

  tlpPowerSave = {
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
    ./virtual-services.nix
    ../../modules/laptop.nix
  ];

  isLaptop = true;

  # ASUS/ROG
  services.asusd = {
    enable = true;
    enableUserService = true;
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

  # Nix
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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
    loadModels = ollamaModels;
    package = pkgs.ollama-cuda;
  };

  services.open-webui = {
    enable = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      OFFLINE_MODE = "true";
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

  specialisation.igpu-only.configuration = {
    system.nixos.tags = [ "igpu-only" ];

    # Disable Nvidia
    services.xserver.videoDrivers = lib.mkForce [ "amdgpu" ];
    hardware.nvidia.prime.sync.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    boot.blacklistedKernelModules = blacklistNvidia;
    boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (m: "blacklist ${m}") blacklistNvidia;

    hyprland.monitorConfig = "eDP-1,2880x1800@60,0x0,1.6";

    # Power management
    services.power-profiles-daemon.enable = lib.mkForce false;
    services.tlp = {
      enable = true;
      settings = tlpPowerSave;
    };

    # Disable heavy services
    services.grafana.enable = lib.mkForce false;
    services.prometheus.enable = lib.mkForce false;
    services.ollama.enable = lib.mkForce false;
    services.open-webui.enable = lib.mkForce false;
  };

  system.stateVersion = "25.05";
  programs.wireshark.enable = true;
}
