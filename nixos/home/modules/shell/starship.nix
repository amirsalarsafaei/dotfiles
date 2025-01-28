{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      format = "$username$hostname$all";
      add_newline = false;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };

      palette = "catppuccin_macchiato";
      username = {
        format = "\\[[$user]($style)";
        show_always = true;
      };
      hostname = {
        ssh_only = false;
        format = "@[$hostname]($style)\\]";
      };

      os = {
        format = "\\[[$symbol]($style)\\]";
      };
      sudo = {
        format = "\\[[as $symbol]($style)\\]";
      };
      time = {
        format = "\\[[$time]($style)\\]";
      };
      cmd_duration = {
        format = "\\[[ $duration]($style)\\]";
        min_time = 10000;
      };

      package = {
        format = "\\[[$symbol$version]($style)\\]";
        symbol = " ";
      };
      git_branch = {
        format = "\\[[$symbol$branch]($style)\\]";
      };

      aws = {
        format = "\\[[$symbol($profile)(\\($region\\))(\\[$duration\\])]($style)\\]";
        symbol = "󰸏 ";
      };
      bun = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = "󰚅 ";
      };
      c = {
        format = "\\[[$symbol($version(-$name))]($style)\\]";
        symbol = " ";
      };
      deno = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      docker_context = {
        format = "\\[[$symbol$context]($style)\\]";
        symbol = "󰡨 ";
      };
      gcloud = {
        format = "\\[[$symbol$account(\\($region\\))]($style)\\]";
        symbol = "󱇶 ";
      };
      gleam = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = "󰦥 ";
      };
      golang = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = "󰟓 ";
      };
      guix_shell = {
        format = "\\[[$symbol]($style)\\]";
      };
      haskell = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      julia = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      kubernetes = {
        format = "\\[[$symbol$context( \\($namespace\\))]($style)\\]";
        symbol = "󱃾 ";
        disabled = false;
      };
      lua = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      nix_shell = {
        format = "\\[[$symbol$state( \\($name\\))]($style)\\]";
        symbol = "󱄅 ";
      };
      nodejs = {
        detect_files = [
          "package.json"
          ".node-version"
          "!bunfig.toml"
          "!bun.lockb"
        ];
      };
      ocaml = {
        format = "\\[[$symbol($version)(\\($switch_indicator$switch_name\\))]($style)\\]";
        symbol = " ";
      };
      pulumi = {
        format = "\\[[$symbol$stack]($style)\\]";
      };
      python = {
        format = "\\[[$symbol$pyenv_prefix($version)(\\($virtualenv\\))]($style)\\]";
        symbol = " ";
      };
      rlang = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      rust = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      scala = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      terraform = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = "󱁢 ";
      };
      zig = {
        format = "\\[[$symbol($version)]($style)\\]";
        symbol = " ";
      };
      git_status = {
        format = ''(\[$staged$conflicted$deleted$renamed$modified$ahead_behind$untracked$stashed\])'';

        conflicted = "[󰘕$count](bright-red)";
        ahead = "[⇡$count](dimmed green)";
        behind = "[⇣$count](dimmed red)";
        diverged = "[⇕⇡$ahead_count⇣$behind_count](red)";
        untracked = "[󱀶 $count](dimmed red)";
        stashed = "[ $count](dimmed yellow)";
        modified = "[ $count](orange)";
        staged = "[ $count](green)";
        renamed = "[»$count](orange)";
        deleted = "[✘$count](red)";
      };
      directory = {
        format = "\\[[$path]($style)\\]";
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = false;
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = "󰝚 ";
          "Pictures" = " ";
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
