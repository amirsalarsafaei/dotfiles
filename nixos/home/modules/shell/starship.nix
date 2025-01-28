{ config, lib, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "[](fg:#769ff0)"
        "$directory"
        "[](fg:#769ff0 bg:#394260)"
        "$git_branch"
        "$git_status"
        "[](fg:#394260 bg:#212736)"
        "$rust"
        "$golang"
        "$python"
        "$kubernetes"
        "$docker_context"
        "$nodejs"
        "$elixir"
        "$aws"
        "$bug"
        "[](fg:#212736 bg:#1d2230)"
        "$time"
        "$battery"
        "[](fg:#1d2230)"
        "\n$character"
      ];

      directory = {
        style = "fg:#e3e5e5 bg:#769ff0";
        format = "[ $path ]($style)";
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

      git_branch = {
        symbol = "";
        style = "bg:#394260";
        format = "[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)";
      };

      git_status = {
        style = "bg:#394260";
        format = "[[($all_status$ahead$behind )](fg:#769ff0 bg:#394260)]($style)";
        conflicted = "🏳";
        diverged = "😵";
        up_to_date = "✓";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++(\${count})](green)";
        renamed = "👅";
        deleted = "🗑";
        show_ahead_behind_count = true;
        ahead_format = "⇡\${count}";
        diverged_format = "⇕⇡\${ahead_count}⇣\${behind_count}";
        behind_format = "⇣\${count}";
      };

      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };

      python = {
        style = "bg:#212736";
        format = "[ \${symbol}\${pyenv_prefix}(\${version}) (\\(\$virtualenv\\)) ](\$style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#1d2230";
        format = "[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)";
      };
    };
  };
}
