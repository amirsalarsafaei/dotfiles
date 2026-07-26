{ pkgs, ... }:
{
  programs.virt-manager.enable = true;

  users.users.amirsalar.extraGroups = [
    "kvm"
    "libvirtd"
  ];

  virtualisation = {
    libvirtd = {
      enable = true;
      nss.enableGuest = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };
    spiceUSBRedirection.enable = true;
  };
}
