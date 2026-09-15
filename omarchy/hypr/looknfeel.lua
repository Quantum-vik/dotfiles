-- Change the default Omarchy look'n'feel. Linked from ~/dotfiles/omarchy/hypr/looknfeel.lua.

-- Blur behind see-through windows (Omarchy ships it off). kitty's background_opacity lets it show through.
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      vibrancy = 0.17,
    },
  },
})

-- Smaller cursor. Omarchy's 24 draws about 38 px at this laptop's 1.6x scale; 18 draws about 29 px.
-- Apps read these when they start. install.sh sets GTK's cursor-size to match.
hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")

-- No gaps between tiled windows or at the screen edges, as on the Mac (EnableTiledWindowMargins = 0).
hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
