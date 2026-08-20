{ pkgs, config, ... }:
let
  t = config.custom.theme.resolved.colors;
in
{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    disableConfirmationPrompt = true;
    historyLimit = 100000;
    keyMode = "vi";
    tmuxinator.enable = true;
    mouse = true;

    extraConfig = ''
      setw -g xterm-keys on
      set -s escape-time 10                     # faster command sequences
      set -sg repeat-time 600                   # increase repeat timeout
      set -s focus-events on
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB,tmux-256color:RGB"

      # OSC 52 clipboard passthrough - lets remote processes write to local clipboard
      set -g set-clipboard on
      set -ag terminal-features ",xterm-256color:clipboard,tmux-256color:clipboard"
      set -g allow-passthrough on

      set -g prefix2 C-a                        # GNU-Screen compatible prefix

      # ── Keybindings ─────────────────────────────────────
      # Declared in home/modules/keys/registry.nix, rendered to tmux syntax
      # from there, and listed by `keys` / `keys tmux`.
      ${config.custom.keys.rendered.tmux}

      # ── Visual ──────────────────────────────────────────
      set -g status on
      set -g status-position top
      set -g status-justify left
      set -g status-style "bg=${t.base00},fg=${t.base05}"
      set -g message-style "bg=${t.base02},fg=${t.base07}"
      set -g message-command-style "bg=${t.base02},fg=${t.base07}"
      set -g pane-border-style "fg=${t.base02}"
      set -g pane-active-border-style "fg=${t.base0D}"
      set -g pane-border-status off
      set -g mode-style "bg=${t.base0D},fg=${t.base00}"
      set -g display-panes-active-colour "${t.base0D}"
      set -g display-panes-colour "${t.base03}"
      set -g clock-mode-colour "${t.base0D}"
      set -g renumber-windows on

      setw -g window-status-style "fg=${t.base04},bg=${t.base00}"
      setw -g window-status-current-style "fg=${t.base00},bg=${t.base0D},bold"
      setw -g window-status-activity-style "fg=${t.base0A},bg=${t.base00}"
      setw -g window-status-bell-style "fg=${t.base08},bg=${t.base00}"
      setw -g window-status-separator ""
      setw -g window-status-format "#[fg=${t.base00},bg=${t.base02}]#[fg=${t.base05},bg=${t.base02}] #I  #W #{?window_zoomed_flag,󰍉 ,}#[fg=${t.base02},bg=${t.base00}]"
      setw -g window-status-current-format "#[fg=${t.base00},bg=${t.base0D}]#[fg=${t.base00},bg=${t.base0D},bold] #I  #W #{?window_zoomed_flag,󰍉 ,}#[fg=${t.base0D},bg=${t.base00}]"

      set -g status-left-length 48
      set -g status-right-length 100
      set -g status-left "#[fg=${t.base00},bg=${t.base0D},bold]  #S #[fg=${t.base0D},bg=${t.base02}]#[fg=${t.base05},bg=${t.base02}] #H #[fg=${t.base02},bg=${t.base00}] "
      set -g status-right "#{?client_prefix,#[fg=${t.base0A},bg=${t.base00}]#[fg=${t.base00},bg=${t.base0A},bold] 󰌌 PREFIX #[fg=${t.base0A},bg=${t.base00}] ,}#{?pane_synchronized,#[fg=${t.base08},bg=${t.base00}]#[fg=${t.base00},bg=${t.base08},bold] 󰓦 SYNC #[fg=${t.base08},bg=${t.base00}] ,}#[fg=${t.base02},bg=${t.base00}]#[fg=${t.base04},bg=${t.base02}] #{battery_icon_status} #{battery_percentage} #[fg=${t.base0E},bg=${t.base02}]#[fg=${t.base00},bg=${t.base0E},bold] %H:%M #[fg=${t.base0D},bg=${t.base0E}]#[fg=${t.base00},bg=${t.base0D},bold] %a %d %b "

      set-option -g status-interval 5
      set-option -g automatic-rename on

      set-option -g automatic-rename-format "#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{b:pane_current_path}:#{pane_current_command}}"
    '';

    plugins = [
      pkgs.tmuxPlugins.yank
      {
        plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pname = "battery";
          pluginName = "battery";
          version = "2023-12-01";
          src = pkgs.fetchFromGitHub {
            owner = "tmux-plugins";
            repo = "tmux-battery";
            rev = "48fae59ba4503cf345d25e4e66d79685aa3ceb75";
            sha256 = "1gx5f6qylzcqn6y3i1l92j277rqjrin7kn86njvn174d32wi78y8";
          };
        };
      }
    ];
  };
}
