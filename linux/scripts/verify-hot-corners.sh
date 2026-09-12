#!/usr/bin/env bash
# Run AFTER a logout/login to confirm hot corners are live.
UUID="custom-hot-corners-extended@G-dH.github.com"
echo "extension state:"
gnome-extensions info "$UUID" 2>/dev/null | grep -E "State|Version" || echo "  NOT LOADED — did you log out and back in?"
echo
echo "corner actions:"
dconf dump /org/gnome/shell/extensions/custom-hot-corners-extended/ | grep -E "^\[|^action|^command"
