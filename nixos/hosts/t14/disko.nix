{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1"; # confirm with lsblk on the live ISO
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true; # good for SSD
              content = {
                type = "filesystem";
                format = "ext4"; # or btrfs if you prefer subvolumes
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
