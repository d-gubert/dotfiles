-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    -- No gap between windows and no gap to the screen edge. Omarchy defaults
    -- to 5 and 10. The border still marks the focused window, so it keeps the
    -- default size of 2.
    gaps_in = 0,
    gaps_out = 0,
  },
})

-- https://wiki.hypr.land/Configuring/Window-Rules/
-- An opaque terminal. Omarchy tags every window "default-opacity" and then
-- sets 0.985 active and 0.96 inactive on that tag. The "terminal" tag covers
-- alacritty and the Omarchy TUI windows. It misses wezterm, because Hyprland
-- matches the whole class and wezterm reports org.wezfurlong.wezterm, so this
-- names that class as well.
o.window({ tag = "terminal" }, { opacity = "1 1" })
o.window("org\\.wezfurlong\\.wezterm", { opacity = "1 1" })
