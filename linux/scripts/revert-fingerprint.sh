#!/usr/bin/env bash
# Undo install.sh's fingerprint step: remove the source-built libfprint from /usr/local so Ubuntu's
# packaged copy is used again. Fingerprint login stays enabled in PAM (it falls back to the password
# when no reader works); turn it off with: sudo pam-auth-update --disable fprintd-local
set -euo pipefail

sudo rm -f /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2 /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0
sudo ldconfig
sudo systemctl stop fprintd.service 2>/dev/null || true
echo "libfprint now: $(ldconfig -p | awk '/libfprint-2.so.2 /{print $NF; exit}')"
