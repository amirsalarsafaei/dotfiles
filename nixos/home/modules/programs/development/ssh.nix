{
  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    includes = [ "~/.ssh/config.d/sops" ];

    settings."*" = {
      ControlMaster = "auto";
      ControlPath = "~/.ssh/sockets/%r@%h-%p";
      ControlPersist = "10m";

      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;

      AddKeysToAgent = "yes";

      HashKnownHosts = "yes";
      UserKnownHostsFile = "~/.ssh/known_hosts";

      IdentitiesOnly = "yes";
    };

    settings."git.divar.cloud" = {
      IdentityFile = "~/.ssh/divar_ed25519";
      ControlPersist = "1h";
    };
  };

  home.file.".ssh/config.d/.gitkeep".text = "";
  home.file.".ssh/sockets/.gitkeep".text = "";
}
