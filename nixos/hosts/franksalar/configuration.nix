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
    inputs.private.nixosModules.franksalar
    ../../modules/server/services/amirsalarsafaei-com
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

  # The website's SSH front-end owns port 22, so move the real OpenSSH daemon
  # to 2222 (shared default lives in modules/server/security.nix).
  services.openssh.ports = lib.mkForce [ 2222 ];
  # 2223: tuissh's browser bridge (xterm.js WebSocket). nginx also fronts it
  # over TLS at ssh.amirsalarsafaei.com, but open it raw too.
  networking.firewall.allowedTCPPorts = [
    2222
    2223
  ];

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
  };

  system.stateVersion = "25.11";
}
