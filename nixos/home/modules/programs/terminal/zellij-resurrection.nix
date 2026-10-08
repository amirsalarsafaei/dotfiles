{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.zellij.resurrection;
  zellij = config.programs.zellij.package;

  pruneEnded = pkgs.writeShellApplication {
    name = "zellij-prune-ended";
    runtimeInputs = [
      zellij
      pkgs.gawk
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/zellij"

      { zellij list-sessions --no-formatting 2>/dev/null || true; } \
        | awk '/\(EXITED/ { print $1 }' \
        | while IFS= read -r name; do
            for dir in "$cache"/*/session_info/"$name"; do
              if [ -f "$dir/session-layout.kdl" ] && [ ! -e "$dir/session-metadata.kdl" ]; then
                zellij delete-session "$name" >/dev/null 2>&1 || true
                break
              fi
            done
          done
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "zellij-welcome";
    runtimeInputs = [ zellij ] ++ lib.optional cfg.deleteEndedSessions pruneEnded;
    text =
      if cfg.deleteEndedSessions then
        ''
          zellij-prune-ended
          status=0
          zellij --layout welcome "$@" || status=$?
          zellij-prune-ended
          exit "$status"
        ''
      else
        ''
          exec zellij --layout welcome "$@"
        '';
  };
in
{
  options.custom.zellij = {
    resurrection = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Serialize sessions to the cache so they can be resurrected after they exit.";
      };

      serializeViewport = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Store each pane's visible contents and scrollback with the session.";
      };

      scrollbackLines = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 10000;
        description = "Scrollback lines stored per pane when serializeViewport is on; 0 stores the whole buffer.";
      };

      interval = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = "Seconds between session snapshots.";
      };

      deleteEndedSessions = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Delete sessions that were ended on purpose (last tab closed, Quit, killed from the
          session manager or `zellij kill-session`) instead of leaving them resurrectable.
          Sessions cut off by a crash, logout or reboot stay resurrectable. Runs from the
          zellij-welcome launcher before and after each client, and as `zellij-prune-ended`.
        '';
      };
    };

    launcher = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = launcher;
      description = "Terminal entry point: the zellij welcome screen, wrapped with the resurrection policy.";
    };
  };

  config = {
    programs.zellij.settings = {
      session_serialization = cfg.enable;
      serialize_pane_viewport = cfg.serializeViewport;
      scrollback_lines_to_serialize = cfg.scrollbackLines;
      serialization_interval = cfg.interval;
    };

    home.packages = lib.optional cfg.deleteEndedSessions pruneEnded;
  };
}
