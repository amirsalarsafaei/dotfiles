{ currentHostname, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    extraConfig = ''
      local act = wezterm.action
      local config = wezterm.config_builder()
      ${lib.optionalString (currentHostname == "rog") ''
      config.front_end = "WebGpu"
      gpus = wezterm.gui.enumerate_gpus()
      config.webgpu_preferred_adapter = gpus[1]
      ''}
      local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

      -- Setup tabline with custom config
      tabline.setup({
        options = {
          icons_enabled = true,
          theme = 'Catppuccin Mocha',
          section_separators = {
            left = wezterm.nerdfonts.pl_left_hard_divider,
            right = wezterm.nerdfonts.pl_right_hard_divider,
          },
          component_separators = {
            left = wezterm.nerdfonts.pl_left_soft_divider,
            right = wezterm.nerdfonts.pl_right_soft_divider,
          },
          tab_separators = {
            left = wezterm.nerdfonts.pl_left_hard_divider,
            right = wezterm.nerdfonts.pl_right_hard_divider,
          },
        },
        sections = {
          tabline_a = { 'mode' },
          tabline_b = { 'workspace' },
          tabline_c = { 'window' },
          tab_active = {
            'index',
            { 'parent', padding = 0 },
            '/',
            { 'cwd', max_length = 20, padding = { left = 0, right = 1 } },
            { 'zoomed', padding = 0 },
          
          },
          tab_inactive = { 
            'index', 
            { 'parent', padding = { left = 0, right = 1 } },
            { 'process', padding = { left = 0, right = 1 } } 
          },
          tabline_x = { 'ram', 'cpu' },
          tabline_y = { 'datetime', 'battery' },
          tabline_z = { 'domain' },
        },
      })

      -- Set leader key (CTRL+b like tmux)
      config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
      config.disable_default_key_bindings = true
      config.enable_wayland = true

      local direction_keys = {
        h = "Left", j = "Down",
        k = "Up",
        l = "Right",
      }

      -- Helper function for keybinds
      local function is_vim(pane)
        -- this is set by the plugin, and unset on ExitPre in Neovim
        return pane:get_user_vars().IS_NVIM == "true"
      end

      local function split_nav(key)
        return {
          key = key,
          mods = "CTRL",
          action = wezterm.action_callback(function(win, pane)
            if is_vim(pane) then
              -- pass the keys through to vim/nvim
              win:perform_action({
                SendKey = { key = key, mods = "CTRL" },
              }, pane)
            else
              win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
            end
          end),
        }
      end

      -- Basic terminal configuration
      config.bidi_enabled = true
      config.bidi_direction = "LeftToRight"
      config.exit_behavior = "Close"
      config.skip_close_confirmation_for_processes_named = {
        "bash",
        "sh",
        "zsh",
        "fish",
        "tmux",
      }


      -- Better terminal features
      config.scrollback_lines = 100000
      config.enable_kitty_keyboard = true
      config.enable_csi_u_key_encoding = true
      config.term = "wezterm"
      config.set_environment_variables = {
        TERM = "wezterm",
        COLORTERM = "truecolor",
        TERM_PROGRAM = "WezTerm",
      }
      config.enable_scroll_bar = false


      config.font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Regular", stretch = "Normal", style = "Normal" })
      config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
      config.font_size = 13.0

      config.keys = {
        -- Pane navigation (Smart vim-aware)
        split_nav("h"),
        split_nav("j"),
        split_nav("k"),
        split_nav("l"),

        -- Leader key configuration (CTRL+b prefix)
        {
          key = "b",
          mods = "CTRL",
          action = act.SendKey({ key = "b", mods = "CTRL" }),
        },

        -- Pane splits with leader key
        {
          key = "-",
          mods = "LEADER",
          action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
        },
        {
          key = "_",
          mods = "LEADER|SHIFT",
          action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
        },

        -- Pane navigation with leader
        { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
        { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
        { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
        { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

        -- Window management with leader
        { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
        { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
        { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
        { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
        { key = "&", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
        { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
        {
          key = "=",
          mods = "LEADER",
          action = wezterm.action.SplitPane({
            direction = "Down",
            size = { Percent = 20 },
          }),
        },
        {
          key = "+",
          mods = "LEADER|SHIFT",
          action = wezterm.action.SplitPane({
            direction = "Right",
            size = { Percent = 20 },
          }),
        },

        -- Pane resizing
        { key = "H", mods = "ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
        { key = "J", mods = "ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
        { key = "K", mods = "ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
        { key = "L", mods = "ALT", action = act.AdjustPaneSize({ "Right", 5 }) },

        -- Window/Tab navigation
        { key = "Tab", mods = "LEADER", action = act.ActivateLastTab },
        { key = "f", mods = "LEADER", action = act.ShowTabNavigator },

        -- Switch to tabs by number
        { key = "1", mods = "LEADER", action = act.ActivateTab(0) },
        { key = "2", mods = "LEADER", action = act.ActivateTab(1) },
        { key = "3", mods = "LEADER", action = act.ActivateTab(2) },
        { key = "4", mods = "LEADER", action = act.ActivateTab(3) },
        { key = "5", mods = "LEADER", action = act.ActivateTab(4) },
        { key = "6", mods = "LEADER", action = act.ActivateTab(5) },
        { key = "7", mods = "LEADER", action = act.ActivateTab(6) },
        { key = "8", mods = "LEADER", action = act.ActivateTab(7) },
        { key = "9", mods = "LEADER", action = act.ActivateTab(8) },

        -- Pane management
        {
          key = ">",
          mods = "CTRL|SHIFT",
          action = act.RotatePanes("Clockwise"),
        },
        {
          key = "<",
          mods = "CTRL|SHIFT",
          action = act.RotatePanes("CounterClockwise"),
        },

        -- Copy/Paste
        { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
        { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
    
        -- Copy mode (vim-style)
        { 
          key = "[", 
          mods = "LEADER", 
          action = act.ActivateCopyMode,
        },
          
        -- Search mode
        { 
          key = "/", 
          mods = "LEADER", 
          action = act.Search({CaseSensitiveString=""}),
        },

        { 
          key = "?", 
          mods = "LEADER|SHIFT", 
          action = act.Search({CaseSensitiveString=""}),
        },
      
        -- Debug overlay
        {
          key = "D",
          mods = "LEADER|SHIFT",
          action = act.ShowDebugOverlay,
        },
      }

      -- Configure copy mode to be vim-like
      -- Copy mode configuration
      config.key_tables = {
        copy_mode = {
          -- Movement keys
          { key = "h", action = act.CopyMode("MoveLeft") },
          { key = "j", action = act.CopyMode("MoveDown") },
          { key = "k", action = act.CopyMode("MoveUp") },
          { key = "l", action = act.CopyMode("MoveRight") },
          
          -- Word movement
          { key = "w", action = act.CopyMode("MoveForwardWord") },
          { key = "b", action = act.CopyMode("MoveBackwardWord") },
          { key = "e", action = act.CopyMode("MoveForwardWordEnd") },
          { key = "Tab", action = act.CopyMode("MoveForwardWord") },
          { key = "Tab", mods = "SHIFT", action = act.CopyMode("MoveBackwardWord") },
          
          -- Start/End of line
          { key = "0", action = act.CopyMode("MoveToStartOfLine") },
          { key = "$", action = act.CopyMode("MoveToEndOfLineContent") },
          { key = "^", action = act.CopyMode("MoveToStartOfLineContent") },
          
          -- Page movement
         { key = "u", action = act.CopyMode("PageUp") },
          { key = "d", action = act.CopyMode("PageDown") },
          { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
          { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
          
          -- Viewport movement
          { key = "H", action = act.CopyMode("MoveToViewportTop") },
          { key = "M", action = act.CopyMode("MoveToViewportMiddle") },
          { key = "L", action = act.CopyMode("MoveToViewportBottom") },
          
          -- Start/End of document
          { key = "g", action = act.CopyMode("MoveToScrollbackTop") },
          { key = "G", action = act.CopyMode("MoveToScrollbackBottom") },
          
          -- Selection
          { key = "v", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
          { key = "V", action = act.CopyMode({ SetSelectionMode = "Line" }) },
          { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
          
          -- Selection movement
          { key = "o", action = act.CopyMode("MoveToSelectionOtherEnd") },
          { key = "O", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
          
          -- Jump movement
          { key = "f", action = act.CopyMode({ JumpForward = { prev_char = false }}) },
          { key = "F", action = act.CopyMode({ JumpBackward = { prev_char = false }}) },
          { key = "t", action = act.CopyMode({ JumpForward = { prev_char = true }}) },
          { key = "T", action = act.CopyMode({ JumpBackward = { prev_char = true }}) },
          { key = ";", action = act.CopyMode("JumpAgain") },
          { key = ",", action = act.CopyMode("JumpReverse") },
          -- Copy
          {
            key = "y",
            mods = "NONE",
            action = act.Multiple({
              { CopyTo = "ClipboardAndPrimarySelection" },
              act.ScrollToBottom,
              { CopyMode = "Close" },
            }),
          },
          
          -- Cancel/Exit
          { 
            key = "Escape", 
            action = act.Multiple({
              act.ScrollToBottom,
              { CopyMode = "Close" },
            }),
          },
          { 
            key = "q", 
            action = act.Multiple({
              act.ScrollToBottom,
              { CopyMode = "Close" },
            }),
          },
          {
            key = "c",
            mods = "CTRL",
            action = act.Multiple({
              act.ScrollToBottom,
              { CopyMode = "Close" },
            }),
          },
          
          -- Search
          { key = "/", action = act.Search({ CaseSensitiveString = "" }) },
          { key = "?", action = act.Search({ CaseSensitiveString = "" }) },
          { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
          { key = "N", mods = "CTRL|SHIFT", action = act.CopyMode("PriorMatch") },
        },
        
        search_mode = {
          { key = "Escape", action = act.CopyMode("Close") },
          { key = "Enter", action = act.CopyMode("PriorMatch") },
          { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
          { key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
          { key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },
          { key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
          { key = "PageUp", action = act.CopyMode("PriorMatchPage") },
          { key = "PageDown", action = act.CopyMode("NextMatchPage") },
          { key = "UpArrow", action = act.CopyMode("PriorMatch") },
          { key = "DownArrow", action = act.CopyMode("NextMatch") },
        },
      }

      -- Better default options
      config.default_cursor_style = "SteadyBlock"
      config.window_close_confirmation = "AlwaysPrompt"
      config.selection_word_boundary = " \t\n{}[]()\"'`,;:"
      config.inactive_pane_hsb = {
        saturation = 0.9,
        brightness = 0.8,
      }

      config.color_scheme = "Catppuccin Mocha"

      -- Enable tab bar for tabline plugin
      config.enable_tab_bar = true
      config.switch_to_last_active_tab_when_closing_tab = true
      config.hide_tab_bar_if_only_one_tab = false
      config.show_new_tab_button_in_tab_bar = false
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = true
      config.tab_max_width = 32



      -- Window decoration and positioning settings

      config.cursor_blink_rate = 0
      config.window_background_opacity = 0.95
      config.status_update_interval = 1000

      return config
    '';
  };
}
