{ config, pkgs, ... }:
let
  intelBusID = "PCI:0:2:0";
  nvidiaBusID = "PCI:1:0:0";
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  services = {
    asusd = {
      enable = true;
      enableUserService = true;
    };
    supergfxd.enable = true;
  };

  systemd.services.supergfxd.path = [ pkgs.pciutils ];
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];


  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
      vaapiVdpau
      libvdpau
      vulkan-loader
      vulkan-validation-layers
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ intel-vaapi-driver ];
  };
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Enable DRM kernel mode setting
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.production;


    prime = {
      sync.enable = true;

      intelBusId = intelBusID;
      nvidiaBusId = nvidiaBusID;
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # List packages installed in system profile. To search, run:
  environment.sessionVariables = {
    # Essential NVIDIA variables
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # VA-API specific
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    LIBVA_MESSAGING_LEVEL = "1";

    GBM_BACKEND = "nvidia-drm";

    WLR_RENDERER = "vulkan";
    XDG_SESSION_TYPE = "wayland";

    # Basic Wayland support
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";

    SDL_VIDEODRIVER = "wayland";
    GDK_BACKEND = "wayland";
  };


  environment.systemPackages = with pkgs; [
    nvidia-vaapi-driver
    libva
    libvdpau
    vaapiVdpau
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

    seahorse
    gnome-keyring
    libsecret
    libgnome-keyring
    wget
    xdg-utils
    qemu
    zsh
    git
    gnome-keyring
    libsecret
    libgnome-keyring
    networkmanager-fortisslvpn
    iwd
    gcr
    glxinfo
    # Essential for Hyprland + Wayland + NVIDIA
    vulkan-loader
    vulkan-tools
    vulkan-validation-layers
    egl-wayland
    libglvnd
    mesa
    libva-utils

  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
