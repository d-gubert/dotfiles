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

-- A resize mode, the way my i3 config has one. Hyprland calls it a submap:
-- SUPER + R enters it, the keys below resize the focused window, and Return,
-- Escape or SUPER + R leaves it. The Omarchy bar has no submap widget, so a
-- Hyprland notification marks the mode instead.
local resize_step = 100
local resize_notice = nil

local function show_resize_notice()
  if not resize_notice then
    resize_notice = hl.notification.create({ text = "Resize mode", timeout = 3600000 })
  end
end

local function hide_resize_notice()
  if resize_notice then
    resize_notice:dismiss()
    resize_notice = nil
  end
end

local function enter_resize_mode()
  show_resize_notice()
  hl.dispatch(hl.dsp.submap("resize"))
end

local function leave_resize_mode()
  hide_resize_notice()
  hl.dispatch(hl.dsp.submap("reset"))
end

hl.define_submap("resize", function()
  -- Hold a key to keep the resize going.
  local function resize_bind(key, x, y)
    hl.bind(key, hl.dsp.window.resize({ x = x, y = y, relative = true }), { repeating = true })
  end

  -- The home row, the same directions as my i3 mode: j shrinks the width,
  -- semicolon grows it, k shrinks the height and l grows it.
  resize_bind("J", -resize_step, 0)
  resize_bind("SEMICOLON", resize_step, 0)
  resize_bind("K", 0, -resize_step)
  resize_bind("L", 0, resize_step)

  -- The arrow keys, the same directions as my i3 mode.
  resize_bind("LEFT", -resize_step, 0)
  resize_bind("RIGHT", resize_step, 0)
  resize_bind("UP", 0, -resize_step)
  resize_bind("DOWN", 0, resize_step)

  hl.bind("RETURN", leave_resize_mode)
  hl.bind("ESCAPE", leave_resize_mode)
  hl.bind("SUPER + R", leave_resize_mode)

  -- i3 swallows every other key while a mode is active. Do the same, so a
  -- stray key cannot reach the window under the resize mode.
  hl.bind("catchall", hl.dsp.no_op())
end)

o.bind("SUPER + R", "Resize mode", enter_resize_mode)
