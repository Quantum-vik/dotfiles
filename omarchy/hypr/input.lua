-- Personal input overrides, loaded after Omarchy's defaults. Linked from ~/dotfiles/omarchy/hypr/input.lua.
-- Mirrors the Ubuntu machine's GNOME settings (linux/gnome/desktop.dconf).
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
  input = {
    -- US + India, as on GNOME. Left Alt + Right Alt switches, since Super+Space is Omarchy's menu.
    -- These options replace Omarchy's, so its Caps Lock = Compose and both-Shifts = Caps Lock are repeated here.
    kb_layout = "us,in",
    kb_variant = ",",
    kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",

    -- GNOME: 225 ms delay, one repeat every 30 ms.
    repeat_delay = 225,
    repeat_rate = 33,

    -- Mouse wheel keeps traditional scrolling.
    natural_scroll = false,

    touchpad = {
      -- Chosen on purpose, unlike the Mac: natural scrolling and tap-to-click (with tap-and-drag) on.
      natural_scroll = true,
      tap_to_click = true,
      tap_and_drag = true,
      -- Two-finger click is a right click.
      clickfinger_behavior = true,
    },
  },
})
