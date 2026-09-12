#!/usr/bin/env bash
# Undo the 2026-09-13 WhiteSur UI pass, back to stock Ubuntu Yaru.
# Leaves dock, hot corners, shortcuts, touchpad, Vitals, Mission Center and kitty alone.
I=org.gnome.desktop.interface
gsettings set $I gtk-theme 'Yaru-dark'
gsettings set $I icon-theme 'Yaru'
gsettings set $I cursor-theme 'Yaru'
dconf reset /org/gnome/shell/extensions/user-theme/name
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
mkdir -p ~/.config/gtk-4.0.whitesur-off
mv ~/.config/gtk-4.0/* ~/.config/gtk-4.0.whitesur-off/ 2>/dev/null
gsettings set $I font-name 'Ubuntu Sans 11'
gsettings set $I document-font-name 'Sans 11'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Sans Bold 11'
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/warty-final-ubuntu.png'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/ubuntu-wallpaper-d.png'
gsettings reset org.gnome.desktop.screensaver picture-uri
dconf reset -f /org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9/   # GNOME Terminal back to stock
echo "Reverted to Yaru. Log out and back in to reset the shell theme."
echo "libadwaita overrides parked in ~/.config/gtk-4.0.whitesur-off (delete when happy)."
