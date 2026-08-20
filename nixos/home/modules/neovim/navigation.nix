{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) normalKeymap;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      # Neovim half of the seamless Ctrl-hjkl navigation. The zellij half is
      # vim-zellij-navigator (home/modules/programs/terminal/zelij.nix): it sees
      # the keypress first, notices the focused pane is running nvim, and writes
      # the key through to nvim's stdin. Without a plugin on this side nvim would
      # just receive a bare <C-h> and do nothing useful with it — the zellij
      # plugin cannot move nvim's own windows.
      #
      # These commands move between nvim windows, and when there is no window in
      # that direction they shell out to `zellij action move-focus` so the jump
      # continues into the neighbouring zellij pane. Same contract as
      # vim-tmux-navigator had with tmux.
      extraPlugins = [ pkgs.vimPlugins.zellij-nav-nvim ];

      extraConfigLua = ''
        require("zellij-nav").setup()
      '';

      # The *Tab variants fall through to the previous/next zellij tab once there
      # is no pane left horizontally; vertical movement stops at the edge.
      keymaps = [
        (normalKeymap "<C-h>" "<cmd>ZellijNavigateLeftTab<CR>" { desc = "Focus left (nvim window or zellij pane)"; })
        (normalKeymap "<C-j>" "<cmd>ZellijNavigateDown<CR>" { desc = "Focus down (nvim window or zellij pane)"; })
        (normalKeymap "<C-k>" "<cmd>ZellijNavigateUp<CR>" { desc = "Focus up (nvim window or zellij pane)"; })
        (normalKeymap "<C-l>" "<cmd>ZellijNavigateRightTab<CR>" { desc = "Focus right (nvim window or zellij pane)"; })
      ];
    };
  };
}
