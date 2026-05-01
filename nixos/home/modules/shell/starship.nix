{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      format = "$directory$git_branch$git_status$nodejs$python$rust$golang$c$lua$nix_shell$docker_context$kubernetes$character";
      right_format = "$cmd_duration$time";
      add_newline = false;

      character = {
        success_symbol = "[❯](bold bright-green)";
        error_symbol = "[❯](bold bright-red)";
        vimcmd_symbol = "[❮](bold bright-yellow)";
      };

      username = {
        format = "[$user ]($style)";
        show_always = false;
        style_user = "bg:blue fg:black";
      };

      hostname = {
        disabled = true;
      };

      os = {
        format = "[$symbol ]($style)";
        style = "bold bright-white";
        disabled = false;
      };

      sudo = {
        format = "[sudo ]($style)";
        style = "bold bright-red";
      };

      time = {
        format = "[$time ]($style)";
        style = "bold bright-blue";
        disabled = false;
        time_format = "%H:%M:%S";
        use_12hr = false;
      };

      cmd_duration = {
        format = "[$duration ]($style)";
        min_time = 2000;
        style = "bold bright-yellow";
        show_milliseconds = false;
      };

      package = {
        format = "[$version ]($style)";
        style = "bold bright-cyan";
      };

      git_branch = {
        format = "[$branch ]($style)";
        style = "bold purple";
      };

      aws = {
        disabled = true;
      };

      bun = {
        format = "[$version ]($style)";
        style = "bold peach";
      };

      c = {
        format = "[$version ]($style)";
        style = "bold bright-blue";
      };

      deno = {
        format = "[$version ]($style)";
        style = "bold green";
      };

      docker_context = {
        format = "[$context ]($style)";
        style = "bold bright-cyan";
      };

      golang = {
        format = "[$version ]($style)";
        style = "bold cyan";
      };

      kubernetes = {
        format = "[$context ]($style)";
        disabled = false;
        style = "bold blue";
      };

      lua = {
        format = "[$version ]($style)";
        style = "bold blue";
      };

      nix_shell = {
        format = "[󱄅 $state ]($style)";
        style = "bold blue";
        heuristic = true;
      };

      nodejs = {
        format = "[$version ]($style)";
        style = "bold green";
        detect_files = [
          "package.json"
          ".node-version"
          "!bunfig.toml"
          "!bun.lockb"
        ];
      };

      python = {
        format = "[$version ]($style)";
        style = "bold yellow";
      };

      rust = {
        format = "[$version ]($style)";
        style = "bold red";
      };

      terraform = {
        format = "[$version ]($style)";
        style = "bold purple";
      };

      zig = {
        format = "[$version ]($style)";
        style = "bold yellow";
      };

      git_status = {
        format = "$all_status$ahead_behind ";
        conflicted = " $count";
        ahead = "[⇡$count](bold green)";
        behind = "[⇣$count](bold yellow)";
        diverged = "[⇕⇡$ahead_count⇣$behind_count](bold purple)";
        up_to_date = "[✓](bold green)";
        untracked = "[?$count](bold blue)";
        stashed = " $count";
        modified = "[!$count](bold yellow)";
        staged = "[+$count](bold green)";
        renamed = "[»$count](bold purple)";
        deleted = "[✘$count](bold red)";
      };

      directory = {
        format = "[$path]($style) ";
        truncation_length = 5;
        truncation_symbol = "…/";
        truncate_to_repo = false;
        style = "bold cyan";
        read_only = " ";
        read_only_style = "red";
        home_symbol = "~";
        use_os_path_sep = true;
        substitutions = {
          "Documents" = "docs";
          "Downloads" = "dl";
          "Pictures" = "pics";
          "Desktop" = "desk";
          "Projects" = "proj";
          ".config" = "cfg";
          "Development" = "dev";
        };
      };
    };
  };
}
