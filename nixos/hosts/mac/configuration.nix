# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./apple-silicon-support
    ];


  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = false;
    binfmt.emulatedSystems = [ "x86_64-linux" ];
    extraModprobeConfig = ''
      options hid_apple swap_fn_leftctrl=1 iso_layout=0 swap_opt_cmd=1 '';
    m1n1CustomLogo = ./boot-logo.png;
    kernelParams = [ "apple_dcp.show_notch=1" ];
  };


  networking.hostName = "amirsalar"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = true;
      IPv6.Enabled = true;
      Settings = {
        AutoConnect = true;
      };
    };
  };
  # Set your time zone.
  time.timeZone = "Asia/Tehran";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  # Select internationalisation properties. i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.resolved = {
    enable = true;
    fallbackDns = [ "8.8.8.8" "8.8.4.4" ];
  };


  hardware = {
    asahi = {
      peripheralFirmwareDirectory = ./firmware;
      useExperimentalGPUDriver = true;
      # experimentalGPUInstallMode = "driver";
      # setupAsahiSound = true;
      # withRust = true;
    };
    graphics.enable = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };


  services.xserver.xkb.layout = "us,ir";
  services.xserver.xkb.options = "grp:win_space_toggle";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  services.postgresql =
    {
      enable = true;
      package = pkgs.postgresql_16;
      authentication = pkgs.lib.mkOverride 10 ''
                #type database  DBuser  auth-method
                local all       all     trust
        		host  all      all     127.0.0.1/32   trust
        		host all       all     ::1/128        trust
      '';
    };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.amirsalar = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "sudo" "docker" "video" ];
    packages = with pkgs; [
      firefox
      tree
      (chromium.override {
        commandLineArgs = [
          "--ozone-platform-hint=auto"
        ];
      })
    ];
    shell = pkgs.zsh;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    shared-mime-info
    qemu
    kdePackages.plasma-workspace
    dunst
    xdg-utils
    vim
    acpilight
    wget
    alacritty
    bind
    inetutils
    htop
    netcat
    tcpdump
    htop
    bluez
    zsh
    coreutils-full
    libimobiledevice
    ifuse
  ];

  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-qt;
    settings = {
      default-cache-ttl = 2592000;
      max-cache-ttl = 2592000;
    };
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
    enableGlobalCompInit = false;
  };


  # List services that you want to enable:


  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.firewall.enable = false;


  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  programs.dconf.enable = true;
  security = {
    polkit.enable = true;
    pam.services.hyprlock = { };
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;

    };
  };
  virtualisation.docker.enable = true;

  services.udev.extraRules = ''
    	SUBSYSTEM=="backlight", ACTION=="add",
    	RUN+="${pkgs.coreutils-full}/bin/chmod 666 /sys/class/backlight/apple-panel-bl/brightness" 
    	RUN+="${pkgs.coreutils-full}/bin/chmod 666 /sys/class/leds/kbd_backlight/brightness" 
    	'';

  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024;
  }];

  services.logind = {
    lidSwitch = "suspend";
  };

  services.acpid.enable = true;
  systemd.services.nix-cleanup = {
    description = "NixOS generation cleanup";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "nix-cleanup" ''
        ${pkgs.nix}/bin/nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system
        ${pkgs.nix}/bin/nix-collect-garbage
      ''}";
    };
  };

  systemd.timers.nix-cleanup = {
    wantedBy = [ "timers.target" ];
    partOf = [ "nix-cleanup.service" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    xdgOpenUsePortal = true;
  };

  zramSwap.enable = true;

  systemd.services.dhcpcd = {
    # Adding the necessary capabilities
    serviceConfig.CapabilityBoundingSet = [
      "CAP_NET_ADMIN"
      "CAP_NET_BIND_SERVICE"
      "CAP_NET_RAW"
      "CAP_SETGID"
      "CAP_SETUID"
      "CAP_SYS_CHROOT"
      "CAP_KILL" # Added CAP_KILL capability
    ];
  };

  services.blueman.enable = true;
  hardware.keyboard.qmk.enable = true;

  fonts.fontDir.enable = true;
  fonts.fontconfig.enable = true;
}
