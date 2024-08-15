local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.bidi_enabled = true
config.bidi_direction = "LeftToRight"

config.default_prog = {
	"/bin/zsh",
	"-l",
	"-c",
	"tmuxinator personal",
}

config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Regular", stretch = "Normal", style = "Normal" })
config.font_size = 18.0

config.enable_tab_bar = false

config.window_background_opacity = 0.8
config.color_scheme = "Catppuccin Mocha"

return config
