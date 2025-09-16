{
  inputs,
  pkgs,
  secrets,
  ...
}:
{

  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];

  networking.hostName = "amirsalar"; # Define your hostname.
  networking.hosts = {
    # "216.239.38.120"= [
    #    "google.com"
    #    "www.google.com"
    #    "mail.google.com"
    #    "gmail.com"
    #    "accounts.google.com"
    #    "colab.research.google.com"
    #    "ssl.gstatic.com"
    #    "fonts.googleapis.com"
    #    "lh3.googleusercontent.com"
    #    "fonts.gstatic.com"
    #    "www.gstatic.com"
    #    "clients1.google.com"
    #    "clients2.google.com"
    #    "clients3.google.com"
    #    "clients4.google.com"
    #    "clients5.google.com"
    #    "clients6.google.com"
    #    "ogads-pa.clients6.google.com"
    #    "play.google.com"
    #    "workspace.google.com"
    #   ];
  };
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking = {
    networkmanager = {
      enable = true;
      wifi = {
        backend = "iwd";
        powersave = false;
      };
    };
    wireless.enable = false;
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = true;
        };
        Network = {
          ConnectTimeout = 60;
        };
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
    fallbackDns = [
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  services.xserver.xkb.layout = "us,ir";
  services.xserver.xkb.options = "grp:win_space_toggle";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  services.postgresql = {
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
    extraGroups = [
      "wheel"
      "input"
      "sudo"
      "docker"
      "video"
      "kvm"
      "adbuser"
      "audio"
    ];
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
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
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

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
  '';

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

  xdg.autostart.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal
      pkgs.xdg-desktop-portal-gtk
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
    ];
    xdgOpenUsePortal = true;
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.OpenURI" = [ "hyprland" ];
      };
    };

  };

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      bip = "172.26.0.1/16";
    };
  };

  # Zswap configuration
  zramSwap.enable = true;

  # Create a 16GB swapfile
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # 16GB
    }
  ];

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

  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services = {
    sddm.enableGnomeKeyring = true;
    hyprlock = {
      enable = true;
      enableGnomeKeyring = true;
    };
  };

  programs.ssh = {
    startAgent = false;
    askPassword = "${pkgs.seahorse}/bin/seahorse";
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-gnome3;
    settings = {
      default-cache-ttl = 2592000;
      max-cache-ttl = 2592000;
    };
  };

  services.dbus.packages = [
    pkgs.gcr
    pkgs.gnome-keyring
  ];
  services.dbus.enable = true;

  services.prometheus = {
    enable = true;
    port = 9090;
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "local-projects";
        file_sd_configs = [
          {
            files = [
              "/etc/nixos/prometheus-targets/*.yml"
              "/etc/nixos/prometheus-targets/*.yaml"
            ];
            refresh_interval = "1m";
          }
        ];
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d /etc/nixos/prometheus-targets 0775 root users - -"
  ];

  services.grafana = {
    enable = true;
    settings.server.http_port = 3000;
    settings.server.http_addr = "locahost";

    provision.datasources.settings.datasources = [
      {
        name = "Prometheus-System";
        type = "prometheus";
        access = "proxy";
        url = "http://localhost:9090";
        isDefault = true;
        jsonData = {
          scrapeInterval = "15s";
          queryTimeout = "60s";
        };
      }
    ];
  };

  environment.variables = {
    GOOGLE_DEFAULT_CLIENT_ID = secrets.google.clientId;
    GOOGLE_DEFAULT_CLIENT_SECRET = secrets.google.clientSecret;
    GOOGLE_API_KEY = secrets.google.apiKey;
  };

}
