{ pkgs, config, ... }:
let
  t = config.theme;
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

      # Navigation ------
      bind C-c new-session
      bind C-f command-prompt -p find-session 'switch-client -t %%'
      bind BTab switch-client -l  

      # Smart splits that detect SSH sessions
      # Vertical split (Prefix + -)
      bind - run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -v \"\$cmd\"; else tmux split-window -v -c \"#{pane_current_path}\"; fi"
      # Vertical split fresh SSH (Prefix + S--)
      bind S-- run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -v \"\''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}\"; else tmux split-window -v -c \"#{pane_current_path}\"; fi"

      # Horizontal split (Prefix + _)
      bind _ run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -h \"\$cmd\"; else tmux split-window -h -c \"#{pane_current_path}\"; fi"
      # Horizontal split fresh SSH (Prefix + |)
      bind | run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -h \"\''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}\"; else tmux split-window -h -c \"#{pane_current_path}\"; fi"

      # Vertical split 20% (Prefix + =)
      bind = run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -v \"\$cmd\" -l '20%'; else tmux split-window -v -c \"#{pane_current_path}\" -l '20%'; fi"
      # Vertical split 20% fresh SSH (Prefix + S-=)
      bind S-= run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -v \"\''${cmd/ -o ControlMaster=auto/ -o ControlMaster=no}\" -l '20%'; else tmux split-window -v -c \"#{pane_current_path}\" -l '20%'; fi"

      # Horizontal split 20% (Prefix + +)
      bind + run-shell "cmd=\$(ps -o command= -t #{pane_tty} | grep -E '^ssh ' | head -n 1); if [ -n \"\$cmd\" ]; then tmux split-window -h \"\$cmd\" -l '20%'; else tmux split-window -h -c \"#{pane_current_path}\" -l '20%'; fi"
      # Horizontal split 20% fresh SSH (Prefix + S-+)  -- same key as +, kept for symmetry via | above
      # pane navigation
      bind -r h select-pane -L # move left 
      bind -r j select-pane -D # move down 
      bind -r k select-pane -U # move up 
      bind -r l select-pane -R # move right
      bind > swap-pane -D       # swap current pane with the next one
      bind < swap-pane -U       # swap current pane with the previous one


      # pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # window navigation
      unbind n
      unbind p
      bind -r C-h previous-window # select previous window
      bind -r C-l next-window     # select next window
      bind Tab last-window        # move to last active window

      # Theme (aligned with system palette)
      set -g status on
      set -g status-position top
      set -g status-style "bg=${t.bgDark},fg=${t.fg}"
      set -g message-style "bg=${t.surface},fg=${t.fgBright}"
      set -g message-command-style "bg=${t.surface},fg=${t.fgBright}"
      set -g pane-border-style "fg=${t.surface}"
      set -g pane-active-border-style "fg=${t.accent}"
      set -g mode-style "bg=${t.accentAlt},fg=${t.bgDarker}"
      set -g display-panes-active-colour "${t.accent}"
      set -g display-panes-colour "${t.muted}"

      setw -g window-status-style "fg=${t.muted},bg=${t.bgDark}"
      setw -g window-status-current-style "fg=${t.bgDarker},bg=${t.accent},bold"
      setw -g window-status-activity-style "fg=${t.warning},bg=${t.bgDark},bold"
      setw -g window-status-bell-style "fg=${t.bgDarker},bg=${t.urgent},bold"
      setw -g window-status-separator " "
      setw -g window-status-format "#[fg=${t.subtle}]#I #[fg=${t.muted}]#W"
      setw -g window-status-current-format "#[fg=${t.accent},bg=${t.bgDark}]#[fg=${t.bgDarker},bg=${t.accent},bold] #I #[fg=${t.fgBright},bg=${t.accent},bold]#W #[fg=${t.accent},bg=${t.bgDark}]"

      set -g status-left-length 48
      set -g status-right-length 120
      set -g status-left "#[fg=${t.bgDarker},bg=${t.accent}]  #S #[fg=${t.accent},bg=${t.bgDark}]"
      set -g status-right "#[fg=${t.subtle},bg=${t.bgDark}] #{cpu_percentage}  #[fg=${t.subtle},bg=${t.bgDark}]󰁹 #{battery_percentage}  #[fg=${t.fgBright},bg=${t.bgDark}]%a %d %b %H:%M "

      set-option -g status-interval 5
      set-option -g automatic-rename on

      set-option -g automatic-rename-format "#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{b:pane_current_path}:#{pane_current_command}}"

      # Copy Mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
    '';

    plugins = [
      pkgs.tmuxPlugins.cpu
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
