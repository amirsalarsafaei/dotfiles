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
    # Personal site is currently disabled; re-enable when ready.
    # ../../modules/server/services/amirsalarsafaei-com
  ];

  home-manager.users.amirsalar = {
    custom.neovim.enable = lib.mkForce false;
    home.packages = [ pkgs.neovim ];
  };

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
