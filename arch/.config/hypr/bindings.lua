-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Move the focus with the home row, the way my i3 config does: j is left,
-- k is down, l is up and semicolon is right. Omarchy binds three of those
-- keys already, so unbind them first.
hl.unbind("SUPER + J") -- was: Toggle window split
hl.unbind("SUPER + K") -- was: Keybindings
hl.unbind("SUPER + L") -- was: Toggle workspace layout

o.bind("SUPER + J", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + K", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + L", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + SEMICOLON", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Keep the three bindings the home row took over, on a free key each.
o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
o.bind("SUPER + SHIFT + K", "Keybindings", "omarchy-menu-keybindings")

-- Open the browser with SUPER + B, the way my i3 config does. Omarchy keeps
-- its own SUPER + SHIFT + B and SUPER + SHIFT + RETURN.
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
