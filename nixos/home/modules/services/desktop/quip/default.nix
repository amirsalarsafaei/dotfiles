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
      export QUIP_DEEPSEEK_EFFORT=${lib.escapeShellArg cfg.deepseekEffort}
      export QUIP_SHARE_TITLES=${if cfg.shareTitles then "1" else "0"}
      export QUIP_SHARE_SONGS=${if cfg.shareSongs then "1" else "0"}
      export QUIP_NOTES_DIR=${lib.escapeShellArg cfg.notesDir}
      export QUIP_PERSONA=${lib.escapeShellArg (lib.concatStringsSep "\n" cfg.persona)}
      export QUIP_ABOUT=${lib.escapeShellArg cfg.about}
      export QUIP_TIMEZONE=${lib.escapeShellArg cfg.timeZone}
      export PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo
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
      default = "deepseek-flash";
      description = "DeepSeek model used for the greeting.";
    };
    deepseekEffort = lib.mkOption {
      type = lib.types.enum [
        "low"
        "high"
        "max"
      ];
      default = "low";
      description = "DeepSeek thinking effort; the model drafts and discards candidate lines while thinking, and these hidden tokens dominate cost and latency.";
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
    about = lib.mkOption {
      type = lib.types.str;
      default = "Iranian backend engineer, Sharif computer science graduate and former olympiad kid; writes Go and Rust, lives in Neovim on NixOS.";
      description = "One line of background sent with every greeting request.";
    };
    persona = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Backend engineer on authentication and a third-party developer platform: wrote an OAuth server from the RFCs, a gRPC rate limiter, and SSRF and open-redirect defences."
        "Cut an API gateway's OPA policy check from 200 ms to under 5 ms at p99.9 by generating policy code, and contributed to the OPA Envoy plugin along the way."
        "Most-starred personal project is sqlc-pgx-monitoring, an OpenTelemetry tracing library for sqlc and pgx with about 90 stars; also wrote pgx-router and sqlc-pgx-route to send reads to replicas."
        "Codeforces master as BinaryBoy, rated 2124; the last rated contest was in February 2021, so the rating has stayed frozen at its peak ever since."
        "Won silver at Iran's national informatics olympiad in 2019, then ranked 466th of about 155,000 in the national university entrance exam."
        "Sharif University computer science graduate; was a TA for operating systems, probability and programming courses, and tutored IOI hopefuls on shortest paths, DSU, LCA and 2-SAT."
        "Hackathon record: first in an LLM hackathon for fitting a quantized Falcon model into 7 GB without a GPU, first in the Torob learning-to-rank challenge, second in AI Cup."
        "The personal website has a Rust gRPC backend, a Next.js frontend with a 3D model of the laptop running a fake terminal, a snake game, and an SSH TUI at ssh.amirsalarsafaei.com. The blog on it has four posts."
        "Published 'Ultimate Protobuf Error Handling Guide - Part 1' on the blog. There is no Part 2 yet."
        "Wrote llm-lsp.nvim, a Neovim plugin that blends LLM token probabilities with LSP completions; its README opens with an Abstract, like a research paper."
        "Built a Raspberry Pi voice assistant with voice activity detection, face recognition and a Neo4j knowledge graph."
        "GitHub bio: 'Toby Maguire got bit by a spider. Me? Must've been a GNU.' The profile README is a fake cat /proc/self/status and a ps aux listing processes like /usr/bin/aspire."
        "The dotfiles repo has over 300 commits; 88 of them are titled 'some changes', and others are 'many changes' and 'so many changes'."
        "Runs NixOS and Hyprland on a ROG G14, a ThinkPad T14, a home server and an Orange Pi, all from one flake."
        "The wallpaper is a hand-written planet shader with the real moon phase; the other scene is a cel-shaded motherboard that draws the laptop's own CPU die from live topology."
        "Runs several Claude and DeepSeek coding agents at once; each one is a pixel critter on the wallpaper, and clicking a critter cracks a pixel whip at it."
        "Lives in Neovim inside zellij with Ctrl+Space as the prefix; the config's own rules declare every existing keybinding frozen."
        "Keeps fortune, cowsay, ponysay, sl, cmatrix, asciiquarium, cbonsai and oneko installed purely for joy, plus Unity for game-dev side quests."
        "Keeps an Obsidian vault whose daily note rolls unfinished checklist items over to the next day."
        "GPG-signs every commit, so pinentry prompts arrive mid-flow."
        "Self-hosts the personal website on a home server."
        "Iranian; reads the Jalali calendar next to the Gregorian one, and an occasional Persian reference or Hafez line lands well."
        "Has ADHD: hyperfocus that eats whole evenings, rabbit holes, too many open tabs, and a brain that runs at either idle or 100% with nothing in between. Affectionate jokes about it land; clinical or pitying ones do not."
        "Music taste swings hard: Gabriel Albuquerque's epic orchestral covers, Einaudi and Interstellar-style piano, Sleep Token, Evanescence and Icon For Hire, Eminem and NF, heartbroken ballads from Jaymes Young, Sofia Karlberg and Sara Kays, then Persian rap like Zedbazi and Erfan."
      ];
      description = "True facts about the user. Each greeting builds on one, drawn in shuffled rotation alongside today's checklist and recent songs, so every fact gets a turn.";
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
          Restart = "on-failure";
          RestartSec = "10min";
        };
      };

      timers.quip = {
        Unit.Description = "Refresh the lock screen greeting";
        Timer = {
          OnStartupSec = "1m";
          OnCalendar = "*-*-* 05,12,17,21:00:30";
          OnUnitActiveSec = "3h";
          RandomizedDelaySec = "2m";
          Unit = "quip.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
