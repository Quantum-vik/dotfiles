#!/bin/bash
# Run once in a real terminal: sudo bash ~/dotfiles/claude/sudo/install.sh
# Installs zenity and makes sudo started by Claude Code skip the fingerprint.
set -euo pipefail
pacman -S --needed --noconfirm zenity
install -m 755 "$(dirname "$0")/sudo-from-claude" /usr/local/bin/sudo-from-claude
LINE='auth      [success=2 default=ignore] pam_exec.so quiet /usr/local/bin/sudo-from-claude'
if ! grep -qF sudo-from-claude /etc/pam.d/sudo; then
  cp -a /etc/pam.d/sudo /etc/pam.d/sudo.bak-before-claude
  sed -i "1i $LINE" /etc/pam.d/sudo
fi
echo "--- /etc/pam.d/sudo now:"; cat /etc/pam.d/sudo
