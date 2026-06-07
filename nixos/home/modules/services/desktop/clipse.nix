{ pkgs, config, ... }:
let
  t = config.custom.theme.resolved.colors;

  # clipse reads config.json wholesale into a struct — missing keys become zero
  # values (e.g. empty keybindings), so we ship the full default set with only
  # maxHistory bumped from 100 → 500 to match the old cliphist depth.
  clipseConfig = {
    allowDuplicates = false;
    historyFile = "clipboard_history.json";
    maxHistory = 500;
    logFile = "clipse.log";
    themeFile = "custom_theme.json";
    tempDir = "tmp_files";
    keyBindings = {
      choose = "enter";
      clearSelected = "S";
      down = "down";
      end = "end";
      filter = "/";
      home = "home";
      more = "?";
      nextPage = "right";
      prevPage = "left";
      preview = " ";
      quit = "q";
      remove = "x";
      selectDown = "ctrl+down";
      selectSingle = "s";
      selectUp = "ctrl+up";
      togglePin = "p";
      togglePinned = "tab";
      up = "up";
      yankFilter = "ctrl+s";
    };
    imageDisplay = {
      type = "basic";
      scaleX = 9;
      scaleY = 9;
      heightCut = 2;
    };
  };

  # Map the active base16 palette onto clipse's theme keys (lipgloss hex colors).
  clipseTheme = {
    useCustom = true;
    TitleFore = t.base00;
    TitleBack = t.base0D;
    TitleInfo = t.base0C;
    NormalTitle = t.base05;
    DimmedTitle = t.base03;
    SelectedTitle = t.base0D;
    NormalDesc = t.base04;
    DimmedDesc = t.base03;
    SelectedDesc = t.base0C;
    StatusMsg = t.base0B;
    PinIndicatorColor = t.base0A;
    SelectedBorder = t.base0D;
    SelectedDescBorder = t.base0D;
    FilteredMatch = t.base0A;
    FilterPrompt = t.base0D;
    FilterInfo = t.base03;
    FilterText = t.base05;
    FilterCursor = t.base0D;
    HelpKey = t.base0E;
    HelpDesc = t.base03;
    DividerDot = t.base03;
    PreviewedText = t.base05;
    PreviewBorder = t.base0D;
  };
in
{
  home.packages = [ pkgs.clipse ];

  xdg.configFile."clipse/config.json".text = builtins.toJSON clipseConfig;
  xdg.configFile."clipse/custom_theme.json".text = builtins.toJSON clipseTheme;

  # Background listener captures text + images off the Wayland clipboard.
  # Bound to graphical-session.target (started by uwsm), matching how the
  # previous cliphist service attached — Hyprland runs with systemd.enable
  # off, so we don't rely on a hyprland-specific target existing.
  systemd.user.services.clipse = {
    Unit = {
      Description = "clipse clipboard history listener";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.clipse}/bin/clipse -listen";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
