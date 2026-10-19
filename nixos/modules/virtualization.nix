{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.custom.virtualization;
  user = "qemu-libvirtd";
  home = config.users.users.amirsalar.home;
  virsh = "${lib.getExe' pkgs.libvirt "virsh"} -c qemu:///system";
  awk = lib.getExe pkgs.gawk;
  setfacl = lib.getExe' pkgs.acl "setfacl";
  find = lib.getExe' pkgs.findutils "find";
in
{
  options.custom.virtualization.sharedPaths = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Host directories exposed to virtual machines. When
      virtualisation.libvirtd.qemu.runAsRoot is disabled these are made readable and
      writable by the unprivileged QEMU user, including default ACLs so that newly
      created files and directories inherit access.
    '';
  };

  config = {
    programs.virt-manager.enable = true;

    users.users.amirsalar.extraGroups = [
      "kvm"
      "libvirtd"
    ];

    systemd.services = {
      libvirt-default-network = {
        description = "Activate the libvirt default NAT network";
        after = [ "libvirtd.service" ];
        requires = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          if ${virsh} net-info default > /dev/null 2>&1; then
            ${virsh} net-autostart default > /dev/null
            active="$(${virsh} net-info default | ${awk} '/^Active:/ { print $2 }')"
            if [ "$active" != "yes" ]; then
              ${virsh} net-start default
            fi
          fi
        '';
      };
    }
    // lib.optionalAttrs (!config.virtualisation.libvirtd.qemu.runAsRoot) {
      libvirt-shared-paths = {
        description = "Grant the unprivileged QEMU user access to host paths shared with VMs";
        before = [ "libvirtd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          ${setfacl} -m u:${user}:--x -m m::--x ${lib.escapeShellArg home}

          ${lib.concatMapStrings (path: ''
            ${setfacl} -R -m u:${user}:rwX ${lib.escapeShellArg path}
            ${find} ${lib.escapeShellArg path} -type d -exec ${setfacl} -d -m u:${user}:rwX {} +
          '') cfg.sharedPaths}
        '';
      };
    };

    virtualisation = {
      libvirtd = {
        enable = true;
        nss.enableGuest = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = lib.mkDefault false;
          swtpm.enable = true;
          vhostUserPackages = [ pkgs.virtiofsd ];
          verbatimConfig = ''
            virtiofsd = "${pkgs.virtiofsd}/bin/virtiofsd"
          '';
        };
      };
      spiceUSBRedirection.enable = true;
    };
  };
}
