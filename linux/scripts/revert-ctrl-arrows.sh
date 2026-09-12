#!/usr/bin/env bash
# Undo Ctrl+Arrow workspace switching, restoring Linux word-jump.
K=org.gnome.desktop.wm.keybindings
gsettings set $K switch-to-workspace-left  "['<Super>Page_Up', '<Super><Alt>Left', '<Control><Alt>Left']"
gsettings set $K switch-to-workspace-right "['<Super>Page_Down', '<Super><Alt>Right', '<Control><Alt>Right']"
gsettings set $K move-to-workspace-left    "['<Super><Shift>Page_Up', '<Super><Shift><Alt>Left', '<Control><Shift><Alt>Left']"
gsettings set $K move-to-workspace-right   "['<Super><Shift>Page_Down', '<Super><Shift><Alt>Right', '<Control><Shift><Alt>Right']"
echo "Ctrl+Arrow word-jump restored."
