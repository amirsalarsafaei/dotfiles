{
  inputs,
  secrets,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./disko-config.nix
    ./avosh-bot.nix
    ../../private/hosts/franksalar
    inputs.amirsalarsafaei-com.nixosModules.default
  ];

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

    ssh = {
      enable = true;
      port = 22;
    };
  };

  services.openssh.ports = lib.mkForce [ 2222 ];
  networking.firewall.allowedTCPPorts = [
    2222
    2223
  ];

  documentation.doc.enable = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  boot = {
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    kernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_net"
      "virtio_scsi"
      "virtio_balloon"
      "virtio_console"

      "9p"
      "9pnet_virtio"
    ];

    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
      "virtio_blk"
    ];
  };

  services.qemuGuest.enable = true;

  networking = {
    networkmanager.enable = false;
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
    domain = "";
  };

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
