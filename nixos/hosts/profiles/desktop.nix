{
  lib,
  pkgs,
  secrets,
  config,
  ...
}:
let
  browserPolicy = builtins.toJSON { DefaultBrowserSettingEnabled = false; };
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
        default = "";
        description = ''
          Hyprland monitor rule as `output,mode,position,scale`. Empty leaves every
          monitor at its EDID preferred mode (`preferred`); set it to pin one
          output, usually the laptop panel, to an exact mode and scale. `output`
          is a port name (`DP-9`) or a `desc:` substring (`desc:LG Electronics
          LG Ultra HD`) matched against the monitor description, so the pin
          follows the physical display instead of the port it is plugged into.
        '';
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
  };

  imports = [
    ./greeter.nix
    ../../modules/desktop-networking.nix
    ../../modules/docker.nix
    ../../modules/home-network.nix
    ../../modules/local-kubernetes.nix
    ../../modules/local-monitoring.nix
    ../../modules/local-postgresql.nix
    ../../modules/personal.nix
    ../../modules/power-profile.nix
    ../../modules/ubuntu-vm.nix
  ];

  config = {
    virtualisation.docker.enable = lib.mkDefault true;
    custom = {
      localKubernetes.enable = lib.mkDefault true;
      localMonitoring.enable = lib.mkDefault true;
      localPostgresql.enable = lib.mkDefault true;
      ubuntuVm.enable = lib.mkDefault true;
    };

    environment.pathsToLink = [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];

    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark;
    };

    services.xserver.enable = true;

    services.xserver.xkb = {
      layout = "us,ir";
      options = "grp:alt_shift_toggle,caps:none";
      variant = "";
    };

    services.pipewire = {
      enable = true;
      pulse.enable = true;
      wireplumber.extraConfig."51-airpods" = {
        "wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = true;
        "monitor.bluez.rules" = [
          {
            matches = [ { "device.name" = "bluez_card.CC_22_FE_69_EF_55"; } ];
            # The AirPods controller releases audio by selecting Off. Do not
            # restore that temporary state when the buds reconnect.
            actions.update-props."session.dont-restore-off-profile" = true;
          }
        ];
      };
    };

    services.libinput.enable = true;

    users.users.amirsalar = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "input"
        "sudo"
        "video"
        "kvm"
        "adbuser"
        "audio"
        "networkmanager"
        "dialout"
        "render"
        "libvirt"
        "podman"
        "wireshark"
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

    services.usbmuxd.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    environment.variables.EDITOR = lib.mkForce "vim";

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

    security.polkit.enable = true;

    security.pam.services = {
      login = {
        enableGnomeKeyring = true;
        fprintAuth = false;
      };
      passwd = {
        enableGnomeKeyring = true;
        rules.password.unix.control = lib.mkForce "required";
      };
      hyprlock = {
        enable = true;
        enableGnomeKeyring = true;
      };
    };

    services.gnome.gnome-keyring.enable = true;
    services.gnome.gcr-ssh-agent.enable = false;
    programs.seahorse.enable = true;

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
      pinentryPackage = pkgs.pinentry-qt;
      settings = {
        default-cache-ttl = 3600;
        max-cache-ttl = 86400;
      };
    };

    services.dbus.packages = [
      pkgs.gcr_4
    ];

    environment.variables = {
      GOOGLE_DEFAULT_CLIENT_ID = secrets.google.clientId;
      GOOGLE_DEFAULT_CLIENT_SECRET = secrets.google.clientSecret;
      GOOGLE_API_KEY = secrets.google.apiKey;
    };

    services.pcscd.enable = true;

    services.udev.packages = [
      pkgs.yubikey-personalization
      (pkgs.writeTextFile {
        name = "rog-azoth-udev-rules";
        destination = "/etc/udev/rules.d/70-rog-azoth.rules";
        text = ''
          SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1a83", TAG+="uaccess"
        '';
      })
    ];

  };
}
