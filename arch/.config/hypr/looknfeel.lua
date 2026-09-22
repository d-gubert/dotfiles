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

-- https://wiki.hypr.land/Configuring/Basics/Binds/
hl.config({
  binds = {
    -- Switch to the workspace I am already on and go back to the previous one.
    -- This is i3's workspace_auto_back_and_forth. Omarchy keeps the Hyprland
    -- default of false. Omarchy also sets binds.hide_special_on_workspace_change,
    -- so name only the key that changes here.
    workspace_back_and_forth = true,
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

-- https://wiki.hypr.land/Configuring/Code-Snippets/
-- Smart borders. The border marks the focused window. A workspace that holds
-- one window has nothing to tell apart, so the border only costs 2 px on each
-- edge. w[tv1] selects a workspace with one tiled, visible window, and f[1]
-- covers the fullscreen case. Omarchy already sets rounding to 0, and the gaps
-- above are 0 on every workspace, so the border is the only part left to drop.
o.window({ float = false, workspace = "w[tv1]" }, { border_size = 0 })
o.window({ float = false, workspace = "f[1]" }, { border_size = 0 })
