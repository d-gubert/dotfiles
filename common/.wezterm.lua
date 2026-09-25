local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action
local build_target = wezterm.target_triple

config.color_scheme = 'Catppuccin Mocha (Gogh)'

local is_darwin = build_target:find('darwin') ~= nil

config.font = wezterm.font "FiraCode Nerd Font Mono"
config.font_size = is_darwin and 17 or 10

config.enable_tab_bar = false

config.disable_default_key_bindings = true

-- Defaults are disabled above, so every binding has to be listed here. On macOS
-- these live on CMD: CTRL-C/CTRL-V are needed by the terminal itself, and with
-- defaults off nothing would copy or paste at all.
local mod = is_darwin and 'CMD' or 'CTRL'

-- An uppercase key implies SHIFT: CTRL-SHIFT-C on Linux, but plain CMD-C on macOS.
local function letter(l)
	return is_darwin and l:lower() or l
end

config.keys = {
	{ key = letter 'C', mods = mod, action = act.CopyTo 'Clipboard' },
	{ key = letter 'V', mods = mod, action = act.PasteFrom 'Clipboard' },
	{ key = letter 'P', mods = mod, action = act.ActivateCommandPalette },
	{ key = '-', mods = mod, action = act.DecreaseFontSize },
	{ key = '=', mods = mod, action = act.IncreaseFontSize },
	{ key = '0', mods = mod, action = act.ResetFontSize },
}

if is_darwin then
	-- Send a real Meta/Alt instead of composing accented characters, otherwise
	-- the M- bindings in .tmux.conf and .config/herdr/config.toml never arrive.
	config.send_composed_key_when_left_alt_is_pressed = false
	config.native_macos_fullscreen_mode = true

	-- The tab bar is off, so each window holds one tab, and closing the tab
	-- closes the window. CTRL-Q stays free on Linux for the terminal itself.
	table.insert(config.keys, { key = 'q', mods = 'CMD', action = act.CloseCurrentTab { confirm = true } })

	-- No title bar, so there is nothing to grab; CMD-SHIFT-drag moves the window.
	config.window_decorations = "RESIZE"
	config.mouse_bindings = {
		{ event = { Drag = { streak = 1, button = 'Left' } }, mods = 'CMD|SHIFT', action = act.StartWindowDrag },
	}
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
