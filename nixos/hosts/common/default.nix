{ inputs, pkgs, secrets, ... }: {

  networking.hostName = "amirsalar"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking = {
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";
        powersave = true;
      };
    };
    wireless.iwd = {
      enable = true;
      settings = {
        General.EnableNetworkConfiguration = true;
        IPv6.Enabled = true;
        Settings = {
          AutoConnect = true;
        };
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
    extraGroups = [ "wheel" "input" "sudo" "docker" "video" "kvm" "adbuser" ];
    packages = with pkgs; [
      firefox
      tree
    ];
    shell = pkgs.zsh;
  };

  hardware = {
    graphics.enable = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };


  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = false;
    enableGlobalCompInit = false;
  };

  networking.firewall.enable = false;

  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  programs.dconf.enable = true;

  services.blueman.enable = true;
  hardware.keyboard.qmk.enable = true;

  fonts.fontDir.enable = true;
  fonts.fontconfig.enable = true;

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
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    xdgOpenUsePortal = true;
  };

  virtualisation.docker.enable = true;

  # Zswap configuration
  zramSwap.enable = true;

  # Create a 16GB swapfile
  swapDevices = [{
    device = "/swapfile";
    size = 16 * 1024; # 16GB
  }];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager = {
    defaultSession = "hyprland-uwsm";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;


  # Configure polkit for privilege escalation
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  # Enable GNOME keyring daemon and its components
  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services = {
    sddm.enableGnomeKeyring = true;
  };

  # SSH agent configuration using GNOME Keyring
  programs.ssh = {
    startAgent = false; # Let GNOME Keyring handle SSH keys
    askPassword = "${pkgs.seahorse}/bin/seahorse";
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
    settings = {
      default-cache-ttl = 2592000;
      max-cache-ttl = 2592000;
    };
  };
  systemd.user.services.gnome-keyring = {
    description = "GNOME Keyring SSH Agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=ssh,secrets,pkcs11";
      Restart = "on-failure";
    };
  };

  services.dbus.packages = [ pkgs.gcr pkgs.gnome-keyring ];

  environment.variables = {
    GOOGLE_DEFAULT_CLIENT_ID = secrets.google.clientId;
    GOOGLE_DEFAULT_CLIENT_SECRET = secrets.google.clientSecret;
    GOOGLE_API_KEY = secrets.google.apiKey;
  };

}
