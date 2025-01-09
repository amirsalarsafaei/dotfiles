local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Set leader key (CTRL+b like tmux)
config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1000 }
config.disable_default_key_bindings = true

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

-- Basic terminal configuration (similar to tmux base config)
config.bidi_enabled = true
config.bidi_direction = "LeftToRight"
config.exit_behavior = "Close" -- Similar to tmux's behavior
config.skip_close_confirmation_for_processes_named = {
	"bash",
	"sh",
	"zsh",
	"fish",
	"tmux",
}

-- Enable tab bar with nice features
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.tab_max_width = 32
config.show_tab_index_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true

-- Better terminal features (incorporating tmux-like settings)
config.scrollback_lines = 100000 -- Matching tmux history-limit
config.enable_kitty_keyboard = true -- Better key handling
config.enable_csi_u_key_encoding = true
config.term = "wezterm" -- Similar to tmux's default-terminal setting
config.set_environment_variables = {
	TERM = "wezterm",
	COLORTERM = "truecolor",
	TERM_PROGRAM = "WezTerm",
}
config.enable_scroll_bar = false
config.window_padding = {
	left = 2,
	right = 2,
	top = 8,
	bottom = 0,
}

config.font = wezterm.font("MesloLGS Nerd Font", { weight = "Regular", stretch = "Normal", style = "Normal" })
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.font_size = 13.0

-- Smart pane/vim navigation
config.keys = {
	-- Pane navigation (Smart vim-aware)
	split_nav("h"),
	split_nav("j"),
	split_nav("k"),
	split_nav("l"),

	-- Leader key configuration (CTRL+b prefix)
	{
		key = "b",
		mods = "LEADER|CTRL",
		action = act.SendKey({ key = "b", mods = "CTRL" }),
	},

	-- Pane splits with leader key (like tmux)
	{
		key = "+",
		mods = "LEADER",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "=",
		mods = "LEADER",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},

	-- Pane navigation with leader
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

	-- Window management with leader
	{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
	{ key = "&", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	{
		key = "-",
		mods = "LEADER",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "_",
		mods = "LEADER",
		action = wezterm.action.SplitPane({
			direction = "Down",
			size = { Percent = 20 },
		}),
	},
	{
		key = "+",
		mods = "LEADER",
		action = wezterm.action.SplitPane({
			direction = "Right",
			size = { Percent = 20 },
		}),
	},

	-- Pane resizing (matching tmux's H,J,K,L bindings)
	{ key = "H", mods = "ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "J", mods = "ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "K", mods = "ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "L", mods = "ALT", action = act.AdjustPaneSize({ "Right", 5 }) },

	-- Window/Tab navigation (matching tmux's window navigation)
	{ key = "Tab", mods = "LEADER", action = act.ActivateLastTab }, -- last window

	-- Session/Tab management
	{ key = "f", mods = "LEADER", action = act.ShowTabNavigator }, -- find window

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
	}, -- swap pane next
	{
		key = "<",
		mods = "CTRL|SHIFT",
		action = act.RotatePanes("CounterClockwise"),
	}, -- swap pane previous

	-- Copy/Paste more like terminal
	{ key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
	{ key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
}

-- Better default options
config.default_cursor_style = "SteadyBlock"
config.window_close_confirmation = "AlwaysPrompt"
config.selection_word_boundary = " \t\n{}[]()\"'`,;:"
config.inactive_pane_hsb = {
	saturation = 0.9,
	brightness = 0.8,
}

config.set_environment_variables = {
	TERM = "wezterm",
	COLORTERM = "truecolor",
	TERM_PROGRAM = "WezTerm",
}

config.color_scheme = "Catppuccin Mocha" -- darker, professional, less pink

local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
bar.apply_to_config(config, {
	position = "bottom",
	max_width = 32,
	padding = {
		left = 1,
		right = 1,
	},
	separator = {
		space = 1,
		left_icon = wezterm.nerdfonts.fa_long_arrow_right,
		right_icon = wezterm.nerdfonts.fa_long_arrow_left,
		field_icon = wezterm.nerdfonts.indent_line,
	},
	modules = {
		tabs = {
			active_tab_fg = 4,
			inactive_tab_fg = 6,
		},
		workspace = {
			enabled = true,
			icon = wezterm.nerdfonts.cod_window,
			color = 8,
		},
		leader = {
			enabled = true,
			icon = wezterm.nerdfonts.oct_rocket,
			color = 2,
		},
		pane = {
			enabled = false,
			icon = wezterm.nerdfonts.cod_multiple_windows,
			color = 7,
		},
		username = {
			enabled = true,
			icon = wezterm.nerdfonts.fa_user,
			color = 6,
		},
		hostname = {
			enabled = true,
			icon = wezterm.nerdfonts.cod_server,
			color = 8,
		},
		clock = {
			enabled = true,
			icon = wezterm.nerdfonts.md_calendar_clock,
			color = 5,
		},
		cwd = {
			enabled = true,
			icon = wezterm.nerdfonts.oct_file_directory,
			color = 7,
		},
		spotify = {
			enabled = false,
			icon = wezterm.nerdfonts.fa_spotify,
			color = 3,
			max_width = 64,
			throttle = 15,
		},
	},
})
config.cursor_blink_rate = 0
config.term = "wezterm"

-- Window and pane configurations (tmux-inspired)
config.window_background_opacity = 0.95
config.inactive_pane_hsb = {
	saturation = 0.9,
	brightness = 0.7,
}

-- Status bar updates (like tmux status-interval)
config.status_update_interval = 1000

return config
