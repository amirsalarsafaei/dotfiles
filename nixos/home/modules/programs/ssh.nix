{ config, ... }:
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
  };

  # Append multiplexing settings to sops-managed ssh_config
  home.file.".ssh/config.d/multiplexing".text = ''
    # Global multiplexing settings
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 10m
    ServerAliveInterval 60
    ServerAliveCountMax 3
  '';

  # Ensure SSH sockets directory exists
  home.file.".ssh/sockets/.gitkeep".text = "";
}

