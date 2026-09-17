-- Personal keybindings, loaded after Omarchy's defaults. Linked from ~/dotfiles/omarchy/hypr/bindings.lua.
-- Brings over the Ubuntu machine's GNOME shortcuts where they don't clash with Omarchy's core bindings.
-- See every binding with Super+K.

-- Ctrl+Left/Right switches workspace and Ctrl+Shift+Left/Right takes the window along, four to a
-- screen like GNOME's fixed workspaces (and macOS Spaces). Chosen on purpose: it takes over word-jump in every app.
--
-- Hyprland numbers workspaces across the whole desktop rather than per screen, so each monitor
-- owns a band of four by position: the leftmost gets 1-4, the one to its right 5-8. Stepping
-- stays inside the band of the screen holding focus, so it never jumps to the other screen.
-- Omarchy's Super+1..0 still address workspaces by number, wherever they are.
local WORKSPACES_PER_MONITOR = 4

local function monitor_band(monitor)
  local monitors = hl.get_monitors()
  table.sort(monitors, function(a, b)
    if a.x == b.x then
      return a.y < b.y
    end
    return a.x < b.x
  end)

  for index, candidate in ipairs(monitors) do
    if candidate.name == monitor.name then
      local first = (index - 1) * WORKSPACES_PER_MONITOR + 1
      return first, first + WORKSPACES_PER_MONITOR - 1
    end
  end

  return 1, WORKSPACES_PER_MONITOR
end

local function workspace_step(delta, take_window)
  return function()
    local monitor = hl.get_active_monitor()
    if not monitor then
      return
    end

    local first, last = monitor_band(monitor)
    local active = hl.get_active_workspace()
    local current = (active and active.id and active.id > 0) and active.id or first

    -- Super+N can park another screen's workspace on this one. From there the first step
    -- lands on the nearest workspace of this screen's own band rather than stepping blind.
    local target = math.max(first, math.min(last, current + delta))
    if current < first or current > last then
      target = math.max(first, math.min(last, current))
    end
    if target == current then
      return
    end

    -- A workspace of this band left open on the other screen would take focus over there
    -- instead of switching this screen, so bring it back before the switch.
    local workspace = hl.get_workspace(tostring(target))
    if workspace and workspace.monitor and workspace.monitor.name ~= monitor.name then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(target), monitor = monitor.name }))
    end

    if take_window then
      hl.dispatch(hl.dsp.window.move({ workspace = tostring(target) }))
    else
      hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
    end
  end
end

o.bind("CTRL + LEFT", "Workspace to the left", workspace_step(-1))
o.bind("CTRL + RIGHT", "Workspace to the right", workspace_step(1))
o.bind("CTRL + SHIFT + LEFT", "Move window to the workspace on the left", workspace_step(-1, true))
o.bind("CTRL + SHIFT + RIGHT", "Move window to the workspace on the right", workspace_step(1, true))

-- Super+L locks, as on GNOME. Omarchy's workspace layout toggle moves from Super+L to Super+Alt+L.
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Super+V opens clipboard history, as CopyQ did on GNOME. Omarchy's "universal paste" on Super+V goes away;
-- Ctrl+V still pastes (Ctrl+Shift+V in terminals).
hl.unbind("SUPER + V")
o.bind("SUPER + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")

-- Alt+Shift+4 takes a screenshot, like Cmd+Shift+4 on the Mac: the same smart region picker as Print.
-- code:13 is the 4 key itself, as Omarchy's own Super+Shift+number bindings use, so Shift turning it into "$" can't matter.
o.bind("ALT + SHIFT + code:13", "Screenshot", "omarchy-capture-screenshot")
