{ pkgs, ... }: {
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

      set -g prefix2 C-a                        # GNU-Screen compatible prefix
      bind C-a send-prefix -2

      # Navigation ------
      bind C-c new-session
      bind C-f command-prompt -p find-session 'switch-client -t %%'
      bind BTab switch-client -l  
      bind - split-window -c '#{pane_current_path}' -v
      bind _ split-window -c '#{pane_current_path}' -h
      bind = split-window -c '#{pane_current_path}' -v -l '20%'
      bind + split-window -c '#{pane_current_path}' -h -l '20%'
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

      set -g default-terminal "tmux-256color"

      set-option -g status-interval 5
      set-option -g automatic-rename on

      set-option -g automatic-rename-format "#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{b:pane_current_path}:#{pane_current_command}}"
    '';


    plugins = [
      {
        plugin = pkgs.tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour "macchiato" # latte,frappe, macchiato or mocha

          set -g @catppuccin_window_left_separator ""
          set -g @catppuccin_window_right_separator " "
          set -g @catppuccin_window_middle_separator " █"
          set -g @catppuccin_window_number_position "right"


          set -g @catppuccin_window_default_fill "number"
          set -g @catppuccin_window_default_text "#W"

          set -g @catppuccin_window_current_fill "number"
          set -g @catppuccin_window_current_text "#W"

          set -g @catppuccin_status_modules_right "session"
          set -g @catppuccin_status_modules_left "cpu battery"
          set -g @catppuccin_status_left_separator  " "
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_fill "icon"
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_uptime_text "#(uptime | sed 's/^[^,]*up *//; s/, *[[:digit:]]* user.*//g; s/ day.*, */d /; s/:/h /; s/ min//; s/$/m/')"

          set -g @catppuccin_directory_text "#{pane_current_path}"
        '';
      }
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
