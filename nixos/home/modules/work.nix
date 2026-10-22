{ config, lib, ... }:
{
  options.custom.work = {
    enable = lib.mkEnableOption "work-only programs, services and credentials; set by modules/work.nix on the work laptop";

    networkStateDir = lib.mkOption {
      type = lib.types.str;
      default = "work-net";
      description = "Directory under $XDG_RUNTIME_DIR where work-net-status publishes status.json.";
    };
  };

  config = lib.mkIf config.custom.work.enable {
    home.sessionVariables.GOPRIVATE = "git.divar.cloud";

    programs = {
      git = lib.mkIf config.programs.git.enable {
        settings = {
          user = lib.mkIf (!config.custom.personal.enable) {
            name = "Amirsalar Safaei";
            email = "amirsalar.safaei@divar.ir";
            signingkey = "A3F4BB498206577A";
          };
          url."ssh://git@git.divar.cloud/".insteadOf = "https://git.divar.cloud/";
        };
        includes = [
          {
            path = "${config.home.homeDirectory}/.gitconfig-work";
            condition = "gitdir:${config.home.homeDirectory}/divar/";
          }
        ];
      };

      ssh.settings."git.divar.cloud" = lib.mkIf config.programs.ssh.enable {
        IdentityFile = "~/.ssh/divar_ed25519";
        ControlPersist = "1h";
      };

      zsh.siteFunctions.divar-warm = lib.mkIf config.programs.zsh.enable ''
        if ssh -O check git@git.divar.cloud >/dev/null 2>&1; then
          return 0
        fi
        echo "Warming git.divar.cloud SSH connection..." >&2
        ssh -fNT git@git.divar.cloud
      '';
    };

    home.file = lib.mkIf config.programs.git.enable {
      ".gitconfig-work".text = ''
        [user]
            name = "Amirsalar Safaei"
            email = "amirsalar.safaei@divar.ir"
            signingkey = "A3F4BB498206577A"
        [core]
            excludesFile = "${config.home.homeDirectory}/.gitignore-work"
      '';
      ".gitignore-work".text = ''
        shell.nix
        flake.nix
        .wakatime-project
      '';
    };

  };
}
