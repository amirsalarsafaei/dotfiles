{
  lib,
  pkgs,
  secrets,
  config,
  hostname,
  ...
}:
let
  localMonitoring = config.custom.localMonitoring.enable;
  browserPolicy = builtins.toJSON { DefaultBrowserSettingEnabled = false; };
  collectNvidiaMetrics =
    localMonitoring && hostname == "g14" && builtins.elem "nvidia" config.services.xserver.videoDrivers;
  sshAskpassSkAware = pkgs.writeShellApplication {
    name = "ssh-askpass-sk-aware";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.glib
      pkgs.lxqt.lxqt-openssh-askpass
    ];
    text = ''
      msg="''${1:-Touch your security key to continue}"

      if [ "''${SSH_ASKPASS_PROMPT:-}" = "none" ]; then
        id="$(notify-send -p -u critical -a SSH -i auth-fingerprint-symbolic \
          -h string:x-canonical-private-synchronous:ssh-sk-touch \
          "Touch your YubiKey" "$msg")" || id=""

        cleanup() {
          if [ -n "$id" ]; then
            gdbus call --session \
              --dest org.freedesktop.Notifications \
              --object-path /org/freedesktop/Notifications \
              --method org.freedesktop.Notifications.CloseNotification \
              "$id" >/dev/null 2>&1 || true
          fi
          exit 0
        }
        trap cleanup TERM INT HUP

        while true; do sleep 86400 & wait $!; done
      fi

      exec lxqt-openssh-askpass "$@"
    '';
  };
in
{
  options = {
    hyprland = {
      monitorConfig = lib.mkOption {
        type = lib.types.str;
        default = ",preferred,auto,auto";
        description = "Hyprland monitor configuration string";
      };

      opaqueWindows = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Force all windows fully opaque. With new_optimizations this lets Hyprland
          skip the blur shader entirely (no translucent region to blur), which avoids
          the high CPU cost of blur on GPUs with weak drivers (e.g. Asahi/Apple).
        '';
      };

      compactOutput = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "eDP-1";
        description = ''
          Output name (as `hyprctl monitors` lists it) that gets tighter desktop
          chrome: smaller Hyprland gaps and a slimmer bar. Meant for a small
          laptop panel; every other output keeps the default spacing.
        '';
      };

      xwaylandDpi = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = ''
          Xft.dpi value (96 * the panel's fractional Hyprland scale, e.g. a 1.5x
          scale -> 144) xrdb-merged at Hyprland startup. Paired with
          xwayland.force_zero_scaling (always on, see hyprland.nix): XWayland
          apps stop being pixelated by Xorg's own blocky fractional-scale
          upsampling, but then render at 1x/96dpi unless something tells them
          the real DPI — this is that hint, for XWayland/X11 toolkits that read
          Xft.dpi (GTK2, Qt via QT_AUTO_SCREEN_SCALE_FACTOR, plain X11/Java
          AWT's Linux DPI autodetection). Null (the default) skips the
          exec-once entirely, so hosts on integer scale or with no fractional
          scaling problem are unaffected.
        '';
      };
    };

    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable laptop-specific configuration";
    };

    isWork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable work-specific configuration (work-claude variant, private skills, etc.)";
    };

    custom.localMonitoring.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the local Prometheus, exporters and Grafana stack.";
    };
  };

  imports = [
    ./greeter.nix
    ../../modules/home-network.nix
    ../../modules/personal.nix
    ../../modules/power-profile.nix
  ];

  config = {

    environment.pathsToLink = [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];

    environment.etc.hosts.enable = false;

    systemd.services.local-hosts = {
      wantedBy = [ "network-pre.target" ];
      before = [ "network-pre.target" ];
      restartTriggers = [ config.environment.etc.hosts.source ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "update-local-hosts" ''
          if [[ ! -e /etc/hosts.local ]]; then
            install -m 0644 -o root -g root /dev/null /etc/hosts.local
          fi

          tmp="$(mktemp /etc/.hosts.XXXXXX)"
          trap 'rm -f "$tmp"' EXIT
          cat ${config.environment.etc.hosts.source} /etc/hosts.local > "$tmp"
          chmod 0644 "$tmp"
          chown root:root "$tmp"
          mv "$tmp" /etc/hosts
          trap - EXIT
        '';
      };
    };

    systemd.paths.local-hosts = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = "/etc/hosts.local";
    };

    programs.openvpn3.enable = true;

    networking = {
      networkmanager = {
        enable = true;
        wifi = {
          backend = "iwd";
          powersave = true;
        };
        plugins = with pkgs; [
          networkmanager-openconnect
          networkmanager-openvpn
        ];
        dns = "systemd-resolved";
        settings = {
          logging = {
            level = "INFO";
            domains = "ALL";
          };
        };
      };
      wireless.enable = false;
      wireless.iwd = {
        enable = true;
        settings = {
          General = {
            EnableNetworkConfiguration = false;
            AddressRandomization = "disabled";
          };
          Network = {
            ConnectTimeout = 120;
          };
          Settings = {
            AutoConnect = true;
          };
        };
      };
      firewall = {
        enable = true;
        allowedTCPPorts = [ ];
        allowedUDPPorts = [
          5353
        ];
        checkReversePath = "loose";
        logRefusedConnections = true;
        logRefusedPackets = true;
      };
      nftables.enable = true;
    };
    services.xserver.enable = true;
    services.resolved = {
      enable = true;
      settings.Resolve.FallbackDNS = [
        "8.8.8.8"
        "8.8.4.4"
      ];
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    services.xserver.xkb = {
      layout = "us,ir";
      options = "grp:alt_shift_toggle,caps:none";
      variant = "";
    };

    services.pipewire = {
      enable = true;
      pulse.enable = true;
    };

    services.libinput.enable = true;

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      authentication = pkgs.lib.mkOverride 10 ''
        local all       all     trust
                host  all      all     127.0.0.1/32   trust
                host all       all     ::1/128        trust
      '';
    };

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
        "networkmanager"
        "dialout"
        "disk"
        "render"
        "libvirt"
        "podman"
      ];
      packages = with pkgs; [
        firefox
        tree
      ];
      shell = pkgs.zsh;
    };

    hardware = {
      graphics.enable = true;

      bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings.General.DeviceID = "bluetooth:004C:0000:0000";
      };
    };

    services.usbmuxd = {
      enable = true;
      package = pkgs.usbmuxd2;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    environment.variables.EDITOR = lib.mkForce "nvim";

    environment.etc."opt/chrome/policies/managed/default-browser.json".text = browserPolicy;
    environment.etc."chromium/policies/managed/default-browser.json".text = browserPolicy;

    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = false;
      enableGlobalCompInit = false;
    };

    programs.nix-ld.enable = true;
    programs.dconf.enable = true;
    programs.thunar = {
      enable = true;
      plugins = [ pkgs.thunar-archive-plugin ];
    };
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    services.upower.enable = true;
    services.fwupd.enable = true;

    nix = {
      settings = {
        extra-substituters = [
          "https://devenv.cachix.org"
          "https://nixos-apple-silicon.cachix.org"
        ];
        extra-trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
          "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
        ];
        keep-outputs = true;
        keep-derivations = true;
        fallback = false;
        max-jobs = lib.mkDefault 3;
        cores = lib.mkDefault 4;
        tarball-ttl = 2419200;
        min-free = 1073741824;
        max-free = 5368709120;
      };
      daemonCPUSchedPolicy = lib.mkDefault "batch";
      daemonIOSchedClass = lib.mkDefault "idle";
    };

    services.blueman.enable = true;
    hardware.keyboard.qmk.enable = true;

    fonts.fontDir.enable = true;
    fonts.fontconfig.enable = true;

    services.acpid.enable = true;
    xdg.autostart.enable = true;
    systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
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
        };
      };
    };

    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        bip = "192.168.143.1/24";
        default-address-pools = [
          {
            base = "192.168.144.0/20";
            size = 24;
          }
        ];
      };
    };

    swapDevices = [
      {
        device = "/swapfile";
        size = 16 * 1024;
      }
    ];

    services.displayManager = {
      defaultSession = "hyprland-uwsm";
    };

    services.printing.enable = true;

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

    security.pam.services = {
      login.enableGnomeKeyring = true;
      hyprlock = {
        enable = true;
        enableGnomeKeyring = true;
      };
    };

    services.gnome.gnome-keyring.enable = true;
    services.gnome.gcr-ssh-agent.enable = false;

    programs.ssh = {
      startAgent = true;
      askPassword = lib.getExe sshAskpassSkAware;
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };

    environment.systemPackages = [
      (pkgs.runCommand "ssh-askpass-default" { } ''
        mkdir -p "$out/bin"
        ln -s ${lib.getExe sshAskpassSkAware} "$out/bin/ssh-askpass"
      '')
    ];

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
      pkgs.gcr_4
      pkgs.gnome-keyring
    ];

    services.prometheus.exporters.node = {
      enable = localMonitoring;
      disabledCollectors = [
        "arp"
        "btrfs"
        "drm"
        "edac"
        "entropy"
        "fibrechannel"
        "infiniband"
        "ipvs"
        "nfsd"
        "perf"
        "processes"
        "rapl"
        "schedstat"
        "selinux"
        "sockstat"
        "softnet"
        "timex"
        "udp_queues"
        "wifi"
        "xfs"
        "zfs"
      ];
    };

    services.prometheus.exporters.nvidia-gpu = lib.mkIf collectNvidiaMetrics {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9835;
    };

    services.prometheus.exporters.blackbox = {
      enable = localMonitoring;
      listenAddress = "127.0.0.1";
      port = 9115;
      configFile = ./prometheus/blackbox.yml;
    };

    services.prometheus = {
      enable = localMonitoring;
      port = 9090;
      globalConfig.scrape_interval = "15s";
      scrapeConfigs = [
        {
          job_name = "node_exporter";
          static_configs = [
            { targets = [ "localhost:9100" ]; }
          ];
        }
        {
          job_name = "blackbox_exporter";
          static_configs = [
            { targets = [ "localhost:9115" ]; }
          ];
        }

        {
          job_name = "llama-server";
          bearer_token = "sk-local";
          static_configs = [
            { targets = [ "localhost:18080" ]; }
          ];
        }
      ]
      ++ lib.optionals collectNvidiaMetrics [
        {
          job_name = "nvidia-gpu";
          static_configs = [
            { targets = [ "localhost:9835" ]; }
          ];
        }
      ]
      ++ [
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

    systemd.tmpfiles.rules = lib.optionals localMonitoring [
      "d /etc/nixos/prometheus-targets 0775 root users - -"
    ];

    services.grafana = {
      enable = localMonitoring;
      settings = {
        server.http_port = 3000;
        server.http_addr = "127.0.0.1";
        database.url = "sqlite3:////var/lib/grafana/data/grafana.db?_time_format=sqlite";
        security.secret_key = "abc";
      };

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

    services.pcscd.enable = true;

    services.udev.packages = [ pkgs.yubikey-personalization ];

  };
}
