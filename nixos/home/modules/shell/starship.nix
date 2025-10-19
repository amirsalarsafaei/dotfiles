{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      # Single-line format with concise information
      format = "$directory$git_branch$git_status$nodejs$python$rust$golang$c$lua$nix_shell$docker_context$kubernetes$character";
      add_newline = false;
      # right_format = "$sudo$time";

      # Clean character symbols
      character = {
        success_symbol = "[❯](bold bright-green)";
        error_symbol = "[❯](bold bright-red)";
        vimcmd_symbol = "[❮](bold bright-yellow)"; };

      palette = "catppuccin_macchiato";
      
      username = {
        format = "[$user]($style) ";
        show_always = false;
        style_user = "bg:blue fg:black";
      };
      hostname = {
        disabled = true;
      };

      # Clean system info
      os = {
        format = "[$symbol]($style) ";
        style = "bold bright-white";
        disabled = false;
      };
      sudo = {
        format = "sudo($style) ";
        style = "bold bright-red";
      };
      time = {
        format = "[$time]($style)";
        style = "dim bright-blue";
        disabled = false;
      };
      cmd_duration = {
        format = "[$duration]($style) ";
        min_time = 2000;
        style = "bold bright-yellow";
      };

      package = {
        format = "[ $version]($style) ";
        style = "bold bright-cyan";
      };

      # Clean git branch display
      git_branch = {
        format = "[ $branch]($style) ";
        style = "bold purple";
      };

      # AWS disabled
      aws = {
        disabled = true;
      };
      c = {
        format = "[ $version]($style) ";
        style = "bold bright-blue";
      };
      docker_context = {
        format = "[ $context]($style) ";
        style = "bold bright-cyan";
      };
      golang = {
        format = "[ $version]($style) ";
        style = "bold cyan";
      };
      kubernetes = {
        format = "[ $context]($style) ";
        disabled = false;
        style = "bold blue";
      };
      lua = {
        format = "[ $version]($style) ";
        style = "bold blue";
      };
      nix_shell = {
        format = "[󱄅 $state]($style) ";
        style = "bold blue";
      };
      nodejs = {
        format = "[ $version]($style) ";
        style = "bold green";
        detect_files = ["package.json" ".node-version" "!bunfig.toml" "!bun.lockb"];
      };
      python = {
        format = "[ $version]($style) ";
        style = "bold yellow";
      };
      rust = {
        format = "[ $version]($style) ";
        style = "bold red";
      };
      terraform = {
        format = "[ $version]($style) ";
        style = "bold purple";
      };

      # Simplified git status
      git_status = {
        format = "$all_status$ahead_behind ";
        conflicted = " $count";
        ahead = "[⇡$count](bold green)";
        behind = "[⇣$count](bold yellow)";
        diverged = "[⇕⇡$ahead_count⇣$behind_count](bold purple)";
        up_to_date = "[✓](bold green)";
        untracked = "[?$count](bold blue)";
        stashed = " $count"; 
        modified = "[!$count](bold yellow)";
        staged = "[+$count](bold green)";
        renamed = "[»$count](bold purple)";
        deleted = "[✘$count](bold red)";
      };

      # Improved directory display - more readable path
      directory = {
        format = "[$path]($style) ";
        truncation_length = 5;
        truncation_symbol = "…/";
        truncate_to_repo = false;
        style = "bold cyan";
        read_only = "";
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
    } // builtins.fromTOML (builtins.readFile
      (pkgs.fetchFromGitHub
        {
          owner = "catppuccin";
          repo = "starship";
          rev = "e99ba6b210c0739af2a18094024ca0bdf4bb3225"; # Replace with the latest commit hash
          sha256 = "0ys6rwcb3i0h33ycr580z785zv29wl9rmhiaikymdrhgshji63fp";
        } + /themes/macchiato.toml));
  };
}
