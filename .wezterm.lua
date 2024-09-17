local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.bidi_enabled = true
config.bidi_direction = "LeftToRight"

config.default_prog = {
	"/bin/zsh",
	"-l",
	"-c",
	"tmuxinator mux",
}

config.font = wezterm.font("JetBrainsMono Nerd Font Mono", { weight = "Regular", stretch = "Normal", style = "Normal" })
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
config.font_size = 18.0

config.enable_tab_bar = false

config.color_scheme = "Catppuccin Mocha"

return config
