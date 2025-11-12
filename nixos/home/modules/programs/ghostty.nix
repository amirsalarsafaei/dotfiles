{
	programs.ghostty = {
		enable = true;
		enableZshIntegration = true;
		clearDefaultKeybinds = true;
		settings = {
			# Font Configuration
			font-family = "JetBrains Mono Nerd Font";
			font-size = 13;
			font-style = "normal";

			term = "xterm-256color";

			shell-integration-features = "no-cursor,no-sudo,no-title";
			command = "tmux new-session";

			window-decoration = false;
			window-padding-x = 8;
			window-padding-y = 8;
			resize-overlay = "never";

			unfocused-split-opacity = 0.9;

			# Cursor
			cursor-style = "block";
			cursor-style-blink = false;


			confirm-close-surface = false;
			# Key Bindings
			# Disable all default keybindings
			keybind = [
				"ctrl+shift+plus=increase_font_size:1"
				"ctrl+shift+minus=decrease_font_size:1"
				"ctrl+shift+equal=reset_font_size"
				"ctrl+shift+c=copy_to_clipboard"
				"ctrl+shift+v=paste_from_clipboard"
			];
		};
	};
}
