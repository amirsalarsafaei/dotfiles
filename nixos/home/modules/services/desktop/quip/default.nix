{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.quip;

  python = pkgs.python3.withPackages (ps: [ ps.anthropic ]);

  quip = pkgs.writeShellApplication {
    name = "quip";
    text = ''
      export QUIP_NAME=${lib.escapeShellArg cfg.name}
      export QUIP_PROVIDERS=${lib.escapeShellArg (lib.concatStringsSep " " cfg.providers)}
      export QUIP_ANTHROPIC_MODEL=${lib.escapeShellArg cfg.anthropicModel}
      export QUIP_DEEPSEEK_MODEL=${lib.escapeShellArg cfg.deepseekModel}
      export QUIP_SHARE_TITLES=${if cfg.shareTitles then "1" else "0"}
      export QUIP_SHARE_SONGS=${if cfg.shareSongs then "1" else "0"}
      export QUIP_NOTES_DIR=${lib.escapeShellArg cfg.notesDir}
      export QUIP_PERSONA=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.persona)}
      export QUIP_TIMEZONE=${lib.escapeShellArg cfg.timeZone}
      export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
      export QUIP_PLAYERCTL=${lib.getExe pkgs.playerctl}
      ${lib.concatMapStrings (provider: ''
        export QUIP_${lib.toUpper provider}_KEY_FILE=${lib.escapeShellArg cfg.keyFiles.${provider}}
      '') cfg.providers}
      exec ${lib.getExe python} ${./quip.py} "$@"
    '';
  };
in
{
  options.custom.quip = {
    name = lib.mkOption {
      type = lib.types.str;
      default = lib.toSentenceCase config.home.username;
      description = "Name the lock screen greeting addresses.";
    };
    providers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "anthropic"
          "deepseek"
        ]
      );
      default = [ "deepseek" ];
      description = "LLM providers tried in order; each needs an entry in keyFiles.";
    };
    keyFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        deepseek = "${config.home.homeDirectory}/personal-deepseek";
      };
      description = "Runtime path of the file holding each provider's API key, read when the service runs.";
    };
    anthropicModel = lib.mkOption {
      type = lib.types.str;
      default = "claude-opus-5";
      description = "Claude model used for the greeting.";
    };
    deepseekModel = lib.mkOption {
      type = lib.types.str;
      default = "deepseek-chat";
      description = "DeepSeek model used for the greeting.";
    };
    shareTitles = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Send calendar event titles and open daily-note items to the LLM, rather than only counts and timings.";
    };
    shareSongs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send recently played song titles, taken from the lyricsd cache, to the LLM.";
    };
    persona = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Software engineer on accounting and auth systems: a ledger off by one rial or a session token that outlives its logout is a real bug, not a rounding error."
        "Genuinely brilliant and knows it; praise that sounds earned lands, and so does a roast that assumes the smartest person in the room."
        "Has ADHD: hyperfocus that eats whole evenings, rabbit holes, too many open tabs, and a brain that runs at either idle or 100% with nothing in between. Affectionate jokes about it land; clinical or pitying ones do not."
        "Deeply into high concurrency and parallelism: lock-free structures, race conditions, work-stealing schedulers, and squeezing every core; a data race is a personal insult."
        "Iranian; reads the Jalali calendar next to the Gregorian one, and an occasional Persian reference or Hafez line lands well."
        "Runs a heavily riced NixOS and Hyprland desktop and will happily lose a weekend to a border gradient or a rebuild."
        "Lives in Neovim inside a terminal multiplexer; keybinding muscle memory is sacred."
        "Humor taste: classic hacker wisdom in the vein of Knuth, Dijkstra, Brooks and SICP; dry and understated beats loud."
        "Keeps an Obsidian vault whose daily note rolls unfinished checklist items over to tomorrow, and tomorrow, and tomorrow."
        "Prefers terse, no-fluff communication."
        "Self-hosts a home server and a personal website, and treats the homelab as a hobby rather than a chore."
        "Runs several AI coding agents at once all day, referees their disagreements, and has opinions about their verbosity."
        "Dark sense of humor about yak shaving: fixing the tool that fixes the tool is a lifestyle."
        "GPG-signs commits and tags, so a stray pinentry prompt mid-flow is just part of the day."
        "Auth engineer's reflex: reads any input as hostile until proven otherwise."
        "Tinkers endlessly; the setup is never finished, only paused between rabbit holes."
        "Trusts reality over documentation: verifies against the live system and assumes the local copy is stale."
        "Changes opinion out loud the moment proven wrong; a refuted theory is a good day, not a bruised ego."
        "Debugs from first principles: reproduce it, isolate it, prove the fix, distrust the explanation that felt too neat."
        "Allergic to hand-waving and hype: wants the terse claim with the evidence, not the sales pitch."
        "Won't call something done until the full check passes; 'works on my machine' is not verification."
        "Music taste swings hard: Gabriel Albuquerque's epic orchestral covers, Einaudi and Interstellar-style piano, Sleep Token, Evanescence and Icon For Hire, Eminem and NF, heartbroken ballads from Jaymes Young, Sofia Karlberg and Sara Kays, then Persian rap like Zedbazi and Erfan."
        "Codes to soundtracks; an epic orchestral cover playing during a YAML edit is peak irony."
        "Keeps cowsay, oneko, cmatrix and asciiquarium installed purely for joy, next to a Minecraft launcher and a Unity install for game-dev side quests."
      ];
      description = "Facts about the user added to the greeting prompt so the jokes feel personal.";
    };
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Asia/Tehran";
      description = "IANA time zone the greeting's clock time is computed in; the zone itself is never sent to the LLM.";
    };
    notesDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Documents/amirsalar-vault/daily notes";
      description = "Directory holding YYYY-MM-DD.md daily notes.";
    };
  };

  config = {
    home.packages = [ quip ];

    systemd.user = {
      services.quip = {
        Unit = {
          Description = "Write a fresh LLM greeting for the lock screen";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe quip;
        };
      };

      timers.quip = {
        Unit.Description = "Refresh the lock screen greeting";
        Timer = {
          OnStartupSec = "1m";
          OnCalendar = "*-*-* 05,12,17,21:00:30";
          OnUnitActiveSec = "1h";
          RandomizedDelaySec = "2m";
          Unit = "quip.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
