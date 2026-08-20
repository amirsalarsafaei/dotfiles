{ inputs
, secrets
, lib
, pkgs
, ...
}:
{
  imports = [
    ./disko-config.nix
    ../../private/hosts/franksalar
    inputs.amirsalarsafaei-com.nixosModules.default
    inputs.avosh-bot.nixosModules.default
  ];

  home-manager.users.amirsalar = {
    custom.neovim.enable = lib.mkForce false;
    home.packages = [ pkgs.neovim ];
  };

  # Personal website, built from source via the upstream flake's nix module.
  # nginx reverse proxy + ACME certs live in the private franksalar module.
  services.amirsalarsafaei-com = {
    enable = true;
    domain = "amirsalarsafaei.com";

    authToken = secrets.amirsalarsafaeiCom.authToken;

    database = {
      createLocally = true;
      password = secrets.amirsalarsafaeiCom.dbPassword;
    };

    backend.allowedOrigins = [
      "https://amirsalarsafaei.com"
      "https://www.amirsalarsafaei.com"
    ];

    spotify = {
      clientId = secrets.spotify.clientId;
      clientSecret = secrets.spotify.clientSecret;
      refreshToken = secrets.spotify.refreshToken;
      redirectUri = secrets.spotify.redirectUri;
    };

    # SSH front-end (Wish + Bubble Tea TUI) served on the standard SSH port.
    ssh = {
      enable = true;
      port = 22;
    };
  };

  # Avosh diet bot: Django admin + Mini App (gunicorn on 127.0.0.1:8010) and
  # a Telegram bot process (long polling). nginx reverse proxy + ACME cert
  # live in the private franksalar module, same split as amirsalarsafaei-com
  # above. The app tree is deployed to /etc/avosh-bot out of band (git
  # pull/rsync). franksalar doesn't run sops-nix (useSops = false, see
  # flake.nix), so secrets flow the same way amirsalarsafaeiCom's do above:
  # baked at eval time from the git-crypt-encrypted secrets.json.
  services.avosh-bot.enable = true;

  systemd.services.avosh-bot-env = {
    description = "avosh-bot: install .env from secrets.json";
    before = [ "avosh-bot-migrate.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        let
          envFile = pkgs.writeText "avosh-bot.env" ''
            TELEGRAM_BOT_TOKEN=${secrets.avoshBot.telegramBotToken}
            DJANGO_SECRET_KEY=${secrets.avoshBot.djangoSecretKey}
            DJANGO_DEBUG=False
            PLAN_DAYS=7
            AI_API_KEY=${secrets.avoshBot.aiApiKey}
            AI_BASE_URL=https://api.gapgpt.app/v1
            AI_MODEL=gpt-5.5
            AI_TEMPERATURE=0.2
            AI_INTAKE_ENABLED=True
            AI_INTAKE_PUBLIC=False
            DEVELOPER_TELEGRAM_IDS=176161958
            MINIAPP_URL=https://diet.amirsalarsafaei.com
          '';
        in
        "${pkgs.coreutils}/bin/install -m 0400 -o avosh-bot -g avosh-bot ${envFile} /etc/avosh-bot/.env";
    };
  };

  systemd.services.avosh-bot-migrate = {
    requires = [ "avosh-bot-env.service" ];
    after = [ "avosh-bot-env.service" ];
  };

  # The website's SSH front-end owns port 22, so move the real OpenSSH daemon
  # to 2222 (shared default lives in modules/server/security.nix).
  services.openssh.ports = lib.mkForce [ 2222 ];
  # 2223: tuissh's browser bridge (xterm.js WebSocket). nginx also fronts it
  # over TLS at ssh.amirsalarsafaei.com, but open it raw too.
  networking.firewall.allowedTCPPorts = [
    2222
    2223
  ];

  documentation.doc.enable = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192; # 8 GB
    }
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  boot.kernelModules = [
    # virtio drivers (most common for VPSes)
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_scsi"
    "virtio_balloon"
    "virtio_console"

    # virtio-9p filesystem sharing
    "9p"
    "9pnet_virtio"
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
    "virtio_blk" # crucial for /dev/vda
  ];

  networking.networkmanager.enable = false;
  services.qemuGuest.enable = true;

  networking = {
    useDHCP = false;
    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = secrets.franksalar.ipv4;
          prefixLength = 24;
        }
      ];

      ipv6.addresses = [
        {
          address = secrets.franksalar.ipv6;
          prefixLength = 64;
        }
      ];
    };
    defaultGateway = {
      address = secrets.franksalar.gateway4;
      interface = "ens3";
    };

    defaultGateway6 = {
      address = secrets.franksalar.gateway6;
      interface = "ens3";
    };
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  networking.domain = "";

  custom.user = {
    name = "amirsalar";
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICjztTFp0cZwLYpJvGymNDV/XcrViT73hr90tnkzWAVH primary-user@vps"
    ];
    extraUsers.iman = {
      description = "iman";
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWW0uVLHZb7v9307LhCjxsqEJ4xFQ0Yejqz9V85N1yZ personal_use"
      ];
      packages = with pkgs; [
        delta
        gcc
        gh
        git-lfs
        gnumake
        just
        lazygit
        nodejs_22
        pipx
        pkg-config
        python312
        pyright
        ruff
        sqlite
        tealdeer
        uv
      ];
    };
  };

  system.stateVersion = "25.11";
}
