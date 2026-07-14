local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha (Gogh)'

config.font = wezterm.font "FiraCode"
config.font_size = 11

config.enable_tab_bar = false

return config
