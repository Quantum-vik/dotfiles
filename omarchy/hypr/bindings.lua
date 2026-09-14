-- Personal keybindings, loaded after Omarchy's defaults. Linked from ~/dotfiles/omarchy/hypr/bindings.lua.
-- Brings over the Ubuntu machine's GNOME shortcuts where they don't clash with Omarchy's core bindings.
-- See every binding with Super+K.

-- Ctrl+Left/Right switches workspace and Ctrl+Shift+Left/Right takes the window along, stopping at 1 and 4
-- like GNOME's four fixed workspaces (and macOS Spaces). Chosen on purpose: it takes over word-jump in every app.
local WORKSPACES = 4

local function workspace_step(delta, take_window)
  return function()
    local active = hl.get_active_workspace()
    local current = (active and active.id and active.id > 0) and active.id or 1
    local target = math.max(1, math.min(WORKSPACES, current + delta))
    if target == current then
      return
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
o.rebind("SUPER + L", "Lock system", "omarchy-system-lock")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Super+V opens clipboard history, as CopyQ did on GNOME. Omarchy's "universal paste" on Super+V goes away;
-- Ctrl+V still pastes (Ctrl+Shift+V in terminals).
o.rebind("SUPER + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
