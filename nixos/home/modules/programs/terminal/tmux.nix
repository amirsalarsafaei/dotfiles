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
      bind C-a send-prefix -2

      bind C-c new-session
      bind C-f command-prompt -p find-session 'switch-client -t %%'
      bind BTab switch-client -l

      bind - run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -v "$cmd"; else tmux split-window -v -c "#{pane_current_path}"; fi'
      bind S-- run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -v "''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}"; else tmux split-window -v -c "#{pane_current_path}"; fi'

      bind _ run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -h "$cmd"; else tmux split-window -h -c "#{pane_current_path}"; fi'
      bind | run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -h "''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}"; else tmux split-window -h -c "#{pane_current_path}"; fi'

      bind = run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -v "$cmd" -l 20%; else tmux split-window -v -c "#{pane_current_path}" -l 20%; fi'
      bind S-= run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -v "''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}" -l 20%; else tmux split-window -v -c "#{pane_current_path}" -l 20%; fi'

      bind + run-shell 'cmd=$(ps -o command= -t #{pane_tty} | grep -E "^ssh " | head -n 1); if [ -n "$cmd" ]; then tmux split-window -h "$cmd" -l 20%; else tmux split-window -h -c "#{pane_current_path}" -l 20%; fi'
      bind -r h select-pane -L
      bind -r j select-pane -D
      bind -r k select-pane -U
      bind -r l select-pane -R
      bind > swap-pane -D
      bind < swap-pane -U

      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      unbind n
      unbind p
      bind -r C-h previous-window
      bind -r C-l next-window
      bind Tab last-window

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

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
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
      pkgs.tmuxPlugins.vim-tmux-navigator
    ];
  };
}
