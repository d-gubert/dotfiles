local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.color_scheme = 'Catppuccin Mocha (Gogh)'

config.font = wezterm.font "FiraCode"
config.font_size = 11

config.enable_tab_bar = false

config.disable_default_key_bindings = true

config.keys = {
	{ key = 'C', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
	{ key = 'V', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
	{ key = 'P', mods = 'CTRL', action = act.ActivateCommandPalette },
	{ key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
	{ key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
}

return config
