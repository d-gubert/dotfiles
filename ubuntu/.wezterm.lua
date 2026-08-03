local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local build_target = wezterm.target_triple

config.color_scheme = 'Catppuccin Mocha (Gogh)'

config.font = wezterm.font "FiraCode"
config.font_size = 10

config.enable_tab_bar = false

config.disable_default_key_bindings = true

config.keys = {
	{ key = 'C', mods = 'CTRL', action = act.CopyTo 'Clipboard' },
	{ key = 'V', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
	{ key = 'P', mods = 'CTRL', action = act.ActivateCommandPalette },
	{ key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
	{ key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
	{ key = '0', mods = 'CTRL', action = act.ResetFontSize },
}

if build_target:find('linux') then
	config.audible_bell = "Disabled"

	local sound = '/usr/share/code/resources/app/out/vs/platform/accessibilitySignal/browser/media/terminalBell.mp3'
	local command = '/home/linuxbrew/.linuxbrew/bin/ffplay'
	local child_process = { command, '-nodisp', '-autoexit', '-loglevel', 'quiet', '-volume', '40', sound }

	wezterm.on("bell", function()
		local supported = wezterm.run_child_process({ '[', '-r', sound, '-a', '-x', command, ']' })

		if not supported then return end

		wezterm.background_child_process(child_process)
	end)

end

return config
