{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      # Elegant format with better visual hierarchy and spacing
      format = ''
        $os$username$hostname$directory$git_branch$git_status
        $package$nodejs$python$rust$golang$c$lua$nix_shell
        $docker_context$kubernetes$aws$gcloud$terraform$pulumi
        $cmd_duration$time$line_break$character'';
      
      add_newline = false;
      right_format = "$sudo";

      # Enhanced character symbols with better visual appeal
      character = {
        success_symbol = "❯(bold green)";
        error_symbol = "❯(bold red)";
        vimcmd_symbol = "❮(bold yellow)";
      };

      palette = "catppuccin_macchiato";
      
      # Clean user and host display
      username = {
        format = "⟨$user⟩($style)";
        show_always = true;
        style_user = "bold blue";
      };
      hostname = {
        ssh_only = false;
        format = "@⟨$hostname⟩($style) ";
        style = "bold green";
      };

      # System info with elegant styling
      os = {
        format = "⟨$symbol⟩($style)";
        style = "bold white";
        disabled = false;
      };
      sudo = {
        format = "as ⟨$symbol⟩($style)";
        style = "bold red";
      };
      time = {
        format = "⟨$time⟩($style)";
        style = "bold yellow";
        disabled = false;
      };
      cmd_duration = {
        format = "took ⟨$duration⟩($style)";
        min_time = 2000;
        style = "bold yellow";
      };

      # Enhanced package display
      package = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "📦 ";
        style = "bold cyan";
      };

      # Improved git branch display
      git_branch = {
        format = "$symbol⟨$branch⟩($style) ";
        symbol = " ";
        style = "bold purple";
      };

      # Development environments with modern icons
      aws = {
        format = "⟨$symbol($profile)(\\($region\\))(\\[$duration\\])⟩($style) ";
        symbol = "☁️  ";
        style = "bold yellow";
      };
      bun = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🍞 ";
      };
      c = {
        format = "$symbol⟨$version(-$name)⟩($style) ";
        symbol = " ";
        style = "bold blue";
      };
      deno = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🦕 ";
      };
      docker_context = {
        format = "$symbol⟨$context⟩($style) ";
        symbol = "🐳 ";
        style = "bold blue";
      };
      gcloud = {
        format = "⟨$symbol$account(\\($region\\))⟩($style) ";
        symbol = "☁️  ";
        style = "bold blue";
      };
      gleam = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "⭐ ";
      };
      golang = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🐹 ";
        style = "bold cyan";
      };
      guix_shell = {
        format = "⟨$symbol⟩($style) ";
      };
      haskell = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "λ ";
        style = "bold purple";
      };
      julia = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = " julia ";
        style = "bold purple";
      };
      kubernetes = {
        format = "$symbol⟨$context( \\($namespace\\))⟩($style) ";
        symbol = "⎈ ";
        disabled = false;
        style = "bold blue";
      };
      lua = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🌙 ";
        style = "bold blue";
      };
      nix_shell = {
        format = "$symbol⟨$state( \\($name\\))⟩($style) ";
        symbol = "❄️  ";
        style = "bold blue";
      };
      nodejs = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = " ";
        style = "bold green";
        detect_files = [
          "package.json"
          ".node-version"
          "!bunfig.toml"
          "!bun.lockb"
        ];
      };
      ocaml = {
        format = "$symbol⟨$version(\\($switch_indicator$switch_name\\))⟩($style) ";
        symbol = "🐫 ";
      };
      pulumi = {
        format = "$symbol⟨$stack⟩($style) ";
        symbol = "🛠️  ";
      };
      python = {
        format = "$symbol⟨$pyenv_prefix($version)(\\($virtualenv\\))⟩($style) ";
        symbol = "🐍 ";
        style = "bold yellow";
      };
      rlang = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "📊 ";
      };
      rust = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🦀 ";
        style = "bold red";
      };
      scala = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "🔺 ";
      };
      terraform = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "💠 ";
        style = "bold purple";
      };
      zig = {
        format = "$symbol⟨$version⟩($style) ";
        symbol = "⚡ ";
      };

      # Enhanced git status with better visual hierarchy and cleaner symbols
      git_status = {
        format = ''(⟨$all_status$ahead_behind⟩($style) )'';
        style = "bold red";
        
        # Cleaner and more intuitive symbols
        conflicted = "⚡$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        up_to_date = "✓";
        untracked = "?$count";
        stashed = "⚑$count";
        modified = "!$count";
        staged = "+$count";
        renamed = "»$count";
        deleted = "✘$count";
      };

      # Enhanced directory display with better truncation and visual hierarchy
      directory = {
        format = "⟨$path⟩($style)⟨$read_only⟩($read_only_style) ";
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = true;
        style = "bold cyan";
        read_only = "🔒";
        read_only_style = "red";
        home_symbol = "🏠 ";
        use_os_path_sep = true;
        substitutions = {
          "Documents" = "📚 ";
          "Downloads" = "📥 ";
          "Music" = "🎵 ";
          "Pictures" = "🖼️ ";
          "Videos" = "🎬 ";
          "Desktop" = "🖥️ ";
          "Projects" = "💼 ";
          "Code" = "💻 ";
          ".config" = "⚙️ ";
          "Development" = "🛠️ ";
          "Apps" = "📱 ";
          "Library" = "📖 ";
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
