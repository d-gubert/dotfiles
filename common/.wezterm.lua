local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local build_target = wezterm.target_triple

config.color_scheme = 'Catppuccin Mocha (Gogh)'

local is_darwin = build_target:find('darwin') ~= nil

config.font = wezterm.font "FiraCode"
config.font_size = is_darwin and 13 or 10

config.enable_tab_bar = false

config.disable_default_key_bindings = true

-- Defaults are disabled above, so every binding has to be listed here. On macOS
-- these live on CMD: CTRL-C/CTRL-V are needed by the terminal itself, and with
-- defaults off nothing would copy or paste at all.
local mod = is_darwin and 'CMD' or 'CTRL'

config.keys = {
	{ key = 'C', mods = mod, action = act.CopyTo 'Clipboard' },
	{ key = 'V', mods = mod, action = act.PasteFrom 'Clipboard' },
	{ key = 'P', mods = mod, action = act.ActivateCommandPalette },
	{ key = '-', mods = mod, action = act.DecreaseFontSize },
	{ key = '=', mods = mod, action = act.IncreaseFontSize },
	{ key = '0', mods = mod, action = act.ResetFontSize },
}

if is_darwin then
	-- Send a real Meta/Alt instead of composing accented characters, otherwise
	-- the M- bindings in .tmux.conf and .config/herdr/config.toml never arrive.
	config.send_composed_key_when_left_alt_is_pressed = false
	config.native_macos_fullscreen_mode = true
end

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
