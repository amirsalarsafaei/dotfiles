{ ... }:
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      sync_address = "http://atuin.raspberry.lan";
      sync_frequency = "5m";
      auto_sync = true;
      network_timeout = 3;
      search_mode = "fuzzy";
      filter_mode = "global";
      filter_mode_shell_up_key_binding = "session";
      style = "compact";
      show_preview = true;
      exit_mode = "return-original";
      keymap_mode = "emacs";
      enter_accept = true;
      history_filter = [
        "^secret "
        "^export.*KEY"
        "^export.*TOKEN"
        "^export.*PASSWORD"
        "^export.*SECRET"
      ];
    };
  };
}
