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
