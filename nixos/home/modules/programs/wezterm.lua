local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

-- Setup tabline with enhanced config for Neovim/tmux workflow
tabline.setup({
  options = {
    icons_enabled = true,
    theme = 'Catppuccin Mocha',
    color_overrides = {},
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
    tabline_c = {
      { 'hostname', padding = { left = 2, right = 2 } },
    },
    tab_inactive = {
      { 'index',   padding = { left = 2, right = 1 } },
      { 'process', padding = { left = 1, right = 1 } },
      { 'parent',  max_length = 12,                  padding = { left = 1, right = 1 } },
    },
    tabline_x = {
      { 'ram', padding = { left = 2, right = 1 } },
      { 'cpu', padding = { left = 1, right = 2 } }
    },
    tabline_y = {
      { 'datetime', style = '%H:%M',                  padding = { left = 2, right = 2 } },
      { 'battery',  padding = { left = 1, right = 1 } }
    },
    tabline_z = { 'domain' },
    tab_active = {
      { 'index',   padding = { left = 2, right = 1 } },
      { 'process', padding = { left = 1, right = 1 } },
      { 'parent',  max_length = 15,                  padding = { left = 1, right = 1 } },
      { '/',       padding = { left = 0, right = 0 } },
      { 'cwd',     max_length = 20,                  padding = { left = 0, right = 2 } },
      { 'zoomed',  padding = { left = 1, right = 1 } },
    },
  },
  extensions = {},
})

-- Set leader key (CTRL+b like tmux)
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
config.disable_default_key_bindings = true
config.enable_wayland = true

local direction_keys = {
  h = "Left",
  j = "Down",
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
config.enable_scroll_bar = false

config.font = wezterm.font("JetBrainsMono Nerd Font", { weight = "Regular", stretch = "Normal", style = "Normal" })
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.font_size = 14.0
config.line_height = 1

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
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },
  {
    key = "=",
    mods = "LEADER",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
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
    key = "_",
    mods = "LEADER|SHIFT",
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
  { key = "H",   mods = "ALT",    action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "J",   mods = "ALT",    action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "K",   mods = "ALT",    action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "L",   mods = "ALT",    action = act.AdjustPaneSize({ "Right", 5 }) },

  -- Window/Tab navigation
  { key = "Tab", mods = "LEADER", action = act.ActivateLastTab },
  {
    key = "f",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      local tabs = window:tabs()
      local choices = {}

      for i, tab in ipairs(tabs) do
        local tab_info = tab:get_title()
        local is_active = tab:tab_id() == window:active_tab():tab_id()
        local panes = tab:panes()
        local pane_count = #panes

        -- Get process info from active pane
        local active_pane = tab:active_pane()
        local process_name = active_pane:get_foreground_process_name() or "shell"
        process_name = process_name:match("([^/]+)$") or process_name

        -- Get working directory
        local cwd = active_pane:get_current_working_dir()
        local dir_name = "~"
        if cwd then
          dir_name = cwd.file_path:match("([^/]+)/?$") or "~"
        end

        -- Choose icon based on process
        local icon = "🖥️"
        if process_name:match("nvim") or process_name:match("vim") then
          icon = "📝"
        elseif process_name:match("git") then
          icon = "🌿"
        elseif process_name:match("docker") then
          icon = "🐳"
        elseif process_name:match("node") or process_name:match("npm") or process_name:match("yarn") then
          icon = "📦"
        elseif process_name:match("python") then
          icon = "🐍"
        elseif process_name:match("cargo") or process_name:match("rust") then
          icon = "🦀"
        elseif process_name:match("ssh") then
          icon = "🔗"
        elseif process_name:match("htop") or process_name:match("top") then
          icon = "📊"
        elseif process_name:match("bash") or process_name:match("zsh") or process_name:match("fish") then
          icon = "🐚"
        end

        -- Format display text with more details
        local status = is_active and "●" or "○"
        local pane_info = pane_count > 1 and string.format(" [%d panes]", pane_count) or ""
        local display_text = string.format("%s %s %d: %s (%s) in %s%s",
          status, icon, i, tab_info, process_name, dir_name, pane_info)

        table.insert(choices, {
          id = tostring(tab:tab_id()),
          label = display_text,
        })
      end

      -- Add separator
      table.insert(choices, {
        id = "separator",
        label = "─────────────────────────────────────────",
      })

      -- Add management options
      table.insert(choices, {
        id = "new",
        label = "➕ 📄 Create new tab",
      })

      table.insert(choices, {
        id = "rename",
        label = "✏️ 📝 Rename current tab",
      })

      table.insert(choices, {
        id = "delete",
        label = "🗑️ ❌ Delete tab",
      })

      window:perform_action(act.InputSelector({
        action = wezterm.action_callback(function(win, pane_arg, selected_id)
          if not selected_id or selected_id == "separator" then
            return
          end

          if selected_id == "new" then
            win:perform_action(act.SpawnTab("CurrentPaneDomain"), pane_arg)
            return
          end

          if selected_id == "rename" then
            win:perform_action(act.PromptInputLine({
              description = "Enter new name for tab",
              action = wezterm.action_callback(function(rename_window, _, line)
                if line then
                  rename_window:active_tab():set_title(line)
                end
              end),
            }), pane_arg)
            return
          end

          if selected_id == "delete" then
            -- Show a second selector for tab deletion
            local delete_choices = {}
            local all_tabs_for_delete = win:tabs()

            for i, tab in ipairs(all_tabs_for_delete) do
              local tab_info = tab:get_title()
              local is_active = tab:tab_id() == win:active_tab():tab_id()
              local status = is_active and "●" or "○"
              local warning = is_active and " (CURRENT)" or ""

              table.insert(delete_choices, {
                id = tostring(tab:tab_id()),
                label = string.format("%s %d: %s%s", status, i, tab_info, warning),
              })
            end

            win:perform_action(act.InputSelector({
              action = wezterm.action_callback(function(delete_win, _, delete_id)
                if not delete_id then
                  return
                end

                -- Find the tab to delete
                local tabs_to_check = delete_win:tabs()
                for _, tab in ipairs(tabs_to_check) do
                  if tostring(tab:tab_id()) == delete_id then
                    -- Only close if there's more than one tab
                    if #tabs_to_check > 1 then
                      tab:close()
                    else
                      delete_win:toast_notification("WezTerm", "Cannot close the last tab", nil, 2000)
                    end
                    return
                  end
                end
              end),
              title = "🗑️ Delete Tab - Select tab to close",
              choices = delete_choices,
              fuzzy = false,
              description = "Select tab to delete (Enter to confirm, Esc to cancel)",
            }), pane_arg)
            return
          end

          -- Find and activate the selected tab
          local all_tabs = win:tabs()
          for _, tab in ipairs(all_tabs) do
            if tostring(tab:tab_id()) == selected_id then
              tab:activate()
              return
            end
          end
        end),
        title = "🚀 Tab Navigator - Enhanced tmux-style",
        choices = choices,
        fuzzy = true,
        alphabet = "123456789abcdefghijklmnopqrstuvwxyz",
        description = "Navigate: ↑↓/jk | Select: Enter | New: n | Rename: r | Delete: d | Cancel: Esc",
      }), pane)
    end)
  },

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
    action = act.Search({ CaseSensitiveString = "" }),
  },

  {
    key = "?",
    mods = "LEADER|SHIFT",
    action = act.Search({ CaseSensitiveString = "" }),
  },

  -- Debug overlay
  {
    key = "D",
    mods = "LEADER|SHIFT",
    action = act.ShowDebugOverlay,
  },

  -- Font size adjustment
  {
    key = "+",
    mods = "CTRL|SHIFT",
    action = act.IncreaseFontSize,
  },
  {
    key = "-",
    mods = "CTRL",
    action = act.DecreaseFontSize,
  },
  {
    key = "0",
    mods = "CTRL",
    action = act.ResetFontSize,
  },

  -- Additional tmux-like keybinds
  {
    key = "r",
    mods = "LEADER",
    action = act.ReloadConfiguration,
  },
  {
    key = "R",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "Enter new name for tab",
      action = wezterm.action_callback(function(window, _, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },

  -- Workspace management (tmux-like sessions)
  {
    key = "s",
    mods = "LEADER",
    action = act.ShowLauncherArgs({ flags = "WORKSPACES" }),
  },
  {
    key = "$",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "Enter new name for workspace",
      action = wezterm.action_callback(function(window, _, line)
        if line then
          window:active_workspace():set_title(line)
        end
      end),
    }),
  },

  -- Quick pane creation in specific directions (tmux-like)
  {
    key = "%",
    mods = "LEADER|SHIFT",
    action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
  },
  {
    key = '"',
    mods = "LEADER|SHIFT",
    action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
  },

  -- Window management
  {
    key = "w",
    mods = "LEADER",
    action = act.ShowTabNavigator,
  },
  {
    key = ",",
    mods = "LEADER",
    action = act.PromptInputLine({
      description = "Enter new name for tab",
      action = wezterm.action_callback(function(window, _, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },

  -- Session management
  {
    key = "d",
    mods = "LEADER",
    action = act.DetachDomain("CurrentPaneDomain"),
  },
}

-- Configure copy mode to be vim-like
-- Copy mode configuration
config.key_tables = {
  copy_mode = {
    -- Movement keys
    { key = "h",   action = act.CopyMode("MoveLeft") },
    { key = "j",   action = act.CopyMode("MoveDown") },
    { key = "k",   action = act.CopyMode("MoveUp") },
    { key = "l",   action = act.CopyMode("MoveRight") },

    -- Word movement
    { key = "w",   action = act.CopyMode("MoveForwardWord") },
    { key = "b",   action = act.CopyMode("MoveBackwardWord") },
    { key = "e",   action = act.CopyMode("MoveForwardWordEnd") },
    { key = "Tab", action = act.CopyMode("MoveForwardWord") },
    { key = "Tab", mods = "SHIFT",                                                 action = act.CopyMode("MoveBackwardWord") },

    -- Start/End of line
    { key = "0",   action = act.CopyMode("MoveToStartOfLine") },
    { key = "$",   action = act.CopyMode("MoveToEndOfLineContent") },
    { key = "^",   action = act.CopyMode("MoveToStartOfLineContent") },

    -- Page movement
    { key = "u",   action = act.CopyMode("PageUp") },
    { key = "d",   action = act.CopyMode("PageDown") },
    { key = "u",   mods = "CTRL",                                                  action = act.CopyMode({ MoveByPage = -0.5 }) },
    { key = "d",   mods = "CTRL",                                                  action = act.CopyMode({ MoveByPage = 0.5 }) },

    -- Viewport movement
    { key = "H",   action = act.CopyMode("MoveToViewportTop") },
    { key = "M",   action = act.CopyMode("MoveToViewportMiddle") },
    { key = "L",   action = act.CopyMode("MoveToViewportBottom") },

    -- Start/End of document
    { key = "g",   action = act.CopyMode("MoveToScrollbackTop") },
    { key = "G",   action = act.CopyMode("MoveToScrollbackBottom") },

    -- Selection
    { key = "v",   action = act.CopyMode({ SetSelectionMode = "Cell" }) },
    { key = "V",   action = act.CopyMode({ SetSelectionMode = "Line" }) },
    { key = "v",   mods = "CTRL",                                                  action = act.CopyMode({ SetSelectionMode = "Block" }) },

    -- Selection movement
    { key = "o",   action = act.CopyMode("MoveToSelectionOtherEnd") },
    { key = "O",   action = act.CopyMode("MoveToSelectionOtherEndHoriz") },

    -- Jump movement
    { key = "f",   action = act.CopyMode({ JumpForward = { prev_char = false } }) },
    { key = "F",   action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
    { key = "t",   action = act.CopyMode({ JumpForward = { prev_char = true } }) },
    { key = "T",   action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
    { key = ";",   action = act.CopyMode("JumpAgain") },
    { key = ",",   action = act.CopyMode("JumpReverse") },
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
    { key = "n", mods = "CTRL",                                    action = act.CopyMode("NextMatch") },
    { key = "N", mods = "CTRL|SHIFT",                              action = act.CopyMode("PriorMatch") },
  },

  search_mode = {
    { key = "Escape",    action = act.CopyMode("Close") },
    { key = "Enter",     action = act.CopyMode("PriorMatch") },
    { key = "n",         mods = "CTRL",                          action = act.CopyMode("NextMatch") },
    { key = "p",         mods = "CTRL",                          action = act.CopyMode("PriorMatch") },
    { key = "r",         mods = "CTRL",                          action = act.CopyMode("CycleMatchType") },
    { key = "u",         mods = "CTRL",                          action = act.CopyMode("ClearPattern") },
    { key = "PageUp",    action = act.CopyMode("PriorMatchPage") },
    { key = "PageDown",  action = act.CopyMode("NextMatchPage") },
    { key = "UpArrow",   action = act.CopyMode("PriorMatch") },
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
config.tab_max_width = 40
config.tab_bar_style = {
  new_tab = "",
  new_tab_hover = "",
}

-- Window decoration and positioning settings
config.cursor_blink_rate = 0
config.window_background_opacity = 0.95
config.status_update_interval = 1000
config.window_padding = {
  top = '0.25cell',
  bottom = '0cell',
  right = '5px',
  left = '2px',
}

-- Additional performance and UX improvements
config.automatically_reload_config = true
config.check_for_updates = false
config.window_decorations = "NONE"

-- Better scrolling behavior
config.alternate_buffer_wheel_scroll_speed = 3

-- Mouse bindings for better tmux-like experience
config.mouse_bindings = {
  -- Ctrl-click to open hyperlinks
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor,
  },
  -- Change the default click behavior so that it only selects
  -- text and doesn't open hyperlinks
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection('ClipboardAndPrimarySelection'),
  },
  -- Ctrl+Shift+click to select word
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL|SHIFT',
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor('ClipboardAndPrimarySelection'),
  },
  -- Middle click to paste
  {
    event = { Up = { streak = 1, button = 'Middle' } },
    mods = 'NONE',
    action = act.PasteFrom('Clipboard'),
  },
}


return config
