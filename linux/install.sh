#!/usr/bin/env bash
# Rebuild this Linux desktop on a fresh Ubuntu 24.04 (GNOME 46, Wayland).
#
#   ./install.sh                     run every step, in order
#   ./install.sh configs gnome       run only the named steps
#
# Steps: packages  tools  desktop  configs  gnome  fingerprint  fan
#
# Safe to re-run: each step skips work that is already done, and any existing file
# that differs from the repo is moved to <file>.bak-<timestamp>, never deleted.
# This script contains no credentials. See README.md for what to restore by hand.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"     # .../dotfiles/linux
REPO="$(dirname "$DOT")"                                # .../dotfiles
TS="$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
list() { grep -vE '^\s*(#|$)' "$1"; }
gpg_fpr() { gpg --show-keys --with-colons "$1" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}'; }

# Symlink src -> dst. A dst with identical content is replaced; a differing one is backed up.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    info "ok       ${dst/#$HOME/\~}"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if cmp -s "$src" "$dst"; then rm -f "$dst"
    else mv "$dst" "$dst.bak-$TS"; warn "backed up ${dst/#$HOME/\~} -> .bak-$TS"; fi
  fi
  ln -s "$src" "$dst"; info "linked   ${dst/#$HOME/\~}"
}

# Copy src -> dst only when dst is missing (for apps that rewrite their own config).
seed() {
  local src="$1" dst="$2" mode="${3:-644}"
  if [ -e "$dst" ]; then info "exists   ${dst/#$HOME/\~} (left alone)"; return; fi
  install -D -m "$mode" "$src" "$dst"; info "seeded   ${dst/#$HOME/\~}"
}

# ---------------------------------------------------------------------------
step_packages() {
  sudo -v
  . /etc/os-release

  log "apt repositories: VS Code, pgAdmin, Docker (signing keys checked against pinned fingerprints)"
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o "$TMP/ms.asc"
  [ "$(gpg_fpr "$TMP/ms.asc")" = "BC528686B50D79E339D3721CEB3E94ADBE1229CF" ] || { warn "Microsoft key fingerprint mismatch"; exit 1; }
  gpg --dearmor < "$TMP/ms.asc" > "$TMP/ms.gpg"
  sudo install -D -m 644 "$TMP/ms.gpg" /usr/share/keyrings/microsoft.gpg
  printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/microsoft.gpg\n' \
    | sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null

  curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub -o "$TMP/pga.asc"
  [ "$(gpg_fpr "$TMP/pga.asc")" = "E8697E2EEF76C02D3A6332778881B2A8210976F2" ] || { warn "pgAdmin key fingerprint mismatch"; exit 1; }
  gpg --dearmor < "$TMP/pga.asc" > "$TMP/pga.gpg"
  sudo install -D -m 644 "$TMP/pga.gpg" /usr/share/keyrings/packages-pgadmin-org.gpg
  printf 'Types: deb\nURIs: https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/%s\nSuites: pgadmin4\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/packages-pgadmin-org.gpg\n' "$VERSION_CODENAME" \
    | sudo tee /etc/apt/sources.list.d/pgadmin4.sources >/dev/null

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$TMP/docker.asc"
  [ "$(gpg_fpr "$TMP/docker.asc")" = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88" ] || { warn "Docker key fingerprint mismatch"; exit 1; }
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo install -m 0644 "$TMP/docker.asc" /etc/apt/keyrings/docker.asc
  printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$VERSION_CODENAME" \
    | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null

  log "apt packages ($(list "$DOT/packages/apt.txt" | wc -l) + code + pgadmin4-desktop + Docker Engine)"
  sudo apt-get update
  # shellcheck disable=SC2046
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $(list "$DOT/packages/apt.txt") code pgadmin4-desktop \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  log "Docker: run without sudo (docker group is root-equivalent; takes effect at next login)"
  sudo usermod -aG docker "$USER"
  sudo systemctl enable --now docker containerd

  log "Flathub apps"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  list "$DOT/packages/flatpak.txt" | xargs -r flatpak install --user -y --noninteractive flathub
}

# ---------------------------------------------------------------------------
step_tools() {
  sudo -v
  mkdir -p "$HOME/.local/bin"

  log "Go (latest stable, sha256 from go.dev)"
  if [ -x /usr/local/go/bin/go ]; then info "present: $(/usr/local/go/bin/go version)"; else
    curl -fsSL 'https://go.dev/dl/?mode=json' -o "$TMP/go.json"
    read -r GOFILE GOSHA < <(jq -r '[.[] | select(.stable)][0].files[]
      | select(.os=="linux" and .arch=="amd64" and .kind=="archive") | "\(.filename) \(.sha256)"' "$TMP/go.json")
    curl -fsSL "https://go.dev/dl/$GOFILE" -o "$TMP/$GOFILE"
    echo "$GOSHA  $TMP/$GOFILE" | sha256sum -c -
    sudo tar -C /usr/local -xzf "$TMP/$GOFILE"
    echo 'export PATH="$PATH:/usr/local/go/bin"' | sudo tee /etc/profile.d/go.sh >/dev/null
  fi

  log "uv"
  have uv || [ -x "$HOME/.local/bin/uv" ] || curl -LsSf https://astral.sh/uv/install.sh | sh

  log "lazygit (sha256 from release checksums.txt)"
  if have lazygit; then info "present"; else
    curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest -o "$TMP/lg.json"
    LGURL=$(jq -r '.assets[] | select(.name|test("linux_x86_64\\.tar\\.gz$")) | .browser_download_url' "$TMP/lg.json")
    SUMURL=$(jq -r '.assets[] | select(.name=="checksums.txt") | .browser_download_url' "$TMP/lg.json")
    ( cd "$TMP" && curl -fsSLO "$LGURL" && curl -fsSL "$SUMURL" -o sums.txt \
        && grep " $(basename "$LGURL")\$" sums.txt | sha256sum -c - && tar xzf "$(basename "$LGURL")" lazygit )
    sudo install -m 0755 "$TMP/lazygit" /usr/local/bin/lazygit
  fi

  log "kubectl (sha256 from dl.k8s.io)"
  if have kubectl; then info "present"; else
    KV=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    ( cd "$TMP" && curl -fsSLO "https://dl.k8s.io/release/$KV/bin/linux/amd64/kubectl" \
        && echo "$(curl -fsSL "https://dl.k8s.io/release/$KV/bin/linux/amd64/kubectl.sha256")  kubectl" | sha256sum -c - )
    sudo install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
  fi

  log "AWS CLI v2"
  if have aws; then info "present"; else
    ( cd "$TMP" && curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o aws.zip \
        && unzip -q aws.zip && sudo ./aws/install --update )
  fi

  log "espanso (Wayland build)"
  if have espanso; then info "present"; else
    URL=$(curl -fsSL https://api.github.com/repos/espanso/espanso/releases/latest \
          | jq -r '.assets[] | select(.name=="espanso-debian-wayland-amd64.deb") | .browser_download_url')
    curl -fsSL "$URL" -o "$TMP/espanso.deb"
    sudo apt-get install -y "$TMP/espanso.deb"
    sudo setcap "cap_dac_override+p" "$(command -v espanso)" || true
  fi

  log "Postman (official tarball in ~/.local/share so its self-updater works)"
  if [ -x "$HOME/.local/share/Postman/Postman" ]; then info "present"; else
    curl -fsSL https://dl.pstmn.io/download/latest/linux_64 -o "$TMP/postman.tgz"
    mkdir -p "$HOME/.local/share/Postman"
    tar xzf "$TMP/postman.tgz" -C "$HOME/.local/share/Postman" --strip-components=1
    ln -sf "$HOME/.local/share/Postman/Postman" "$HOME/.local/bin/postman"
  fi

  log "poweralertd 0.3.0 (charger notifications; Ubuntu's 0.2.0 has no options to limit it)"
  if [ -x "$HOME/.local/bin/poweralertd" ]; then info "present"; else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y meson ninja-build libsystemd-dev
    git clone -q --depth 1 --branch 0.3.0 https://git.sr.ht/~kennylevinsen/poweralertd "$TMP/poweralertd"
    [ "$(git -C "$TMP/poweralertd" rev-parse HEAD)" = 2b54c6486b5dd73588a9626f3b211d2ace061fe8 ] \
      || { warn "poweralertd 0.3.0 is not the pinned commit"; exit 1; }
    meson setup "$TMP/poweralertd/build" "$TMP/poweralertd" --buildtype=release -Dman-pages=disabled >/dev/null
    ninja -C "$TMP/poweralertd/build" >/dev/null
    install -D -m 755 "$TMP/poweralertd/build/poweralertd" "$HOME/.local/bin/poweralertd"
  fi

  log "Oh My Zsh + Powerlevel10k (the repo's .zshrc is kept)"
  if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then info "Oh My Zsh present"; else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
  [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ] \
    || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

  log "tmux plugin manager"
  [ -d "$HOME/.tmux/plugins/tpm" ] || git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

  log "login shell -> zsh, default terminal -> kitty"
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo chsh -s "$(command -v zsh)" "$USER"
  sudo update-alternatives --set x-terminal-emulator /usr/bin/kitty

  log "Citrix Workspace app (SHA-256 from the Citrix download page; optional components off)"
  if dpkg -s icaclient >/dev/null 2>&1; then info "present"; else
    local ua="Mozilla/5.0 (X11; Linux x86_64)" curl_url sha
    if curl -fsSL -A "$ua" -o "$TMP/citrix.html" \
         https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html; then
      read -r curl_url sha < <(python3 "$DOT/scripts/citrix-latest.py" "$TMP/citrix.html")
      if [ "$curl_url" != "-" ] && [ "$sha" != "-" ]; then
        curl -fsSL -A "$ua" -o "$TMP/icaclient.deb" "$curl_url"
        echo "$sha  $TMP/icaclient.deb" | sha256sum -c -
        printf '%s\n' "icaclient app_protection/install_app_protection select no" \
          "icaclient devicetrust/install_devicetrust select no" "icaclient epa/install_epa select no" | sudo debconf-set-selections
        sudo cp "$TMP/icaclient.deb" /var/cache/apt/archives/icaclient-latest.deb
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /var/cache/apt/archives/icaclient-latest.deb
      else warn "Citrix download link or checksum not found on the page; install Citrix Workspace manually"; fi
    else warn "Citrix download page unreachable; skipping"; fi
  fi
  if [ -d /opt/Citrix/ICAClient/keystore/cacerts ]; then
    info "Citrix: trusting Ubuntu's root certificates (prevents SSL error 61)"
    for c in /usr/share/ca-certificates/mozilla/*.crt; do
      d="/opt/Citrix/ICAClient/keystore/cacerts/$(basename "$c")"; [ -e "$d" ] || sudo ln -s "$c" "$d"
    done
    sudo /opt/Citrix/ICAClient/util/ctx_rehash /opt/Citrix/ICAClient/keystore/cacerts >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
step_desktop() {
  local fonts="$HOME/.local/share/fonts" ws="$TMP/whitesur"
  mkdir -p "$ws"

  log "fonts: MesloLGS NF (Powerlevel10k glyphs), Monocraft (VS Code editor)"
  mkdir -p "$fonts/MesloLGS-NF" "$fonts/Monocraft"
  for v in Regular Bold Italic "Bold Italic"; do
    f="$fonts/MesloLGS-NF/MesloLGS NF $v.ttf"
    [ -f "$f" ] || curl -fsSL -o "$f" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20${v// /%20}.ttf"
  done
  if [ -z "$(ls -A "$fonts/Monocraft" 2>/dev/null)" ]; then
    curl -fsSL https://api.github.com/repos/IdreesInc/Monocraft/releases/latest -o "$TMP/mc.json"
    url=$(jq -r '.assets[] | select(.name=="Monocraft-ttf.zip") | .browser_download_url' "$TMP/mc.json")
    sha=$(jq -r '.assets[] | select(.name=="Monocraft-ttf.zip") | .digest' "$TMP/mc.json" | sed 's/^sha256://')
    curl -fsSL "$url" -o "$TMP/mc.zip"
    echo "$sha  $TMP/mc.zip" | sha256sum -c -
    unzip -qjo "$TMP/mc.zip" '*.ttf' -d "$fonts/Monocraft"
  fi
  fc-cache -f

  wsrepo() { [ -d "$ws/$1" ] || git clone -q --depth=1 "https://github.com/vinceliuice/$1.git" "$ws/$1"; }

  log "WhiteSur GTK + shell theme, icons, cursors"
  # Do NOT run WhiteSur's tweaks.sh -d: it rewrites the dock settings.
  [ -d "$HOME/.themes/WhiteSur-Dark" ] || { wsrepo WhiteSur-gtk-theme; ( cd "$ws/WhiteSur-gtk-theme" && ./install.sh -c dark -l ); }
  [ -d "$HOME/.local/share/icons/WhiteSur-dark" ] || { wsrepo WhiteSur-icon-theme; ( cd "$ws/WhiteSur-icon-theme" && ./install.sh -t default ); }
  [ -d "$HOME/.local/share/icons/WhiteSur-cursors" ] || { wsrepo WhiteSur-cursors; ( cd "$ws/WhiteSur-cursors" && ./install.sh ); }

  log "macOS-style dynamic wallpapers"
  # The wallpaper installer never creates this directory, so cp writes a *file* with its name.
  local props="$HOME/.local/share/gnome-background-properties"
  [ -f "$props" ] && rm -f "$props"
  mkdir -p "$props"
  [ -d "$HOME/.local/share/backgrounds/Sonoma" ] || { wsrepo WhiteSur-wallpapers; ( cd "$ws/WhiteSur-wallpapers" && ./install-gnome-backgrounds.sh -s 1080p ); }

  log "kitty background image (Sonoma dark, cropped to 16:9; kitty 0.32 needs PNG)"
  if [ -f "$HOME/.config/kitty/sonoma-dark.png" ]; then info "present"; else
    mkdir -p "$HOME/.config/kitty"
    python3 - <<'PY'
import gi, os
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
p = os.path.expanduser
pb = GdkPixbuf.Pixbuf.new_from_file(p("~/.local/share/backgrounds/Sonoma/Sonoma-dark.jpg"))
w = pb.get_width()
crop = pb.new_subpixbuf(0, int(pb.get_height() * 0.30), w, w * 9 // 16)
crop.scale_simple(1920, 1080, GdkPixbuf.InterpType.HYPER).savev(p("~/.config/kitty/sonoma-dark.png"), "png", [], [])
PY
  fi

  log "GNOME extensions from extensions.gnome.org (active after next login)"
  local shellv; shellv=$(gnome-shell --version | awk '{print int($3)}')
  while read -r uuid pk; do
    case "$uuid" in \#*|"") continue ;; esac
    if [ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]; then info "ok       $uuid"; continue; fi
    dl=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=$pk&shell_version=$shellv" | jq -r '.download_url')
    curl -fsSL "https://extensions.gnome.org$dl" -o "$TMP/ext.zip"
    gnome-extensions install --force "$TMP/ext.zip"; info "installed $uuid"
  done < "$DOT/packages/gnome-extensions.txt"
}

# ---------------------------------------------------------------------------
step_configs() {
  log "symlinked configs (editing them edits this repo)"
  link "$DOT/shell/zshrc"        "$HOME/.zshrc"
  link "$DOT/shell/zshenv"       "$HOME/.zshenv"
  link "$DOT/shell/p10k.zsh"     "$HOME/.p10k.zsh"
  if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    link "$DOT/shell/aliases.zsh" "$HOME/.oh-my-zsh/custom/aliases.zsh"
  else
    warn "Oh My Zsh not installed yet: run the 'tools' step, then 'configs' again for aliases.zsh"
  fi
  link "$DOT/kitty/kitty.conf"   "$HOME/.config/kitty/kitty.conf"
  link "$REPO/tmux/tmux.conf"    "$HOME/.tmux.conf"
  for f in settings.json keybindings.json statusline.sh CLAUDE.md; do link "$REPO/claude/$f" "$HOME/.claude/$f"; done

  log "seeded configs (written only if missing; these apps rewrite their own files)"
  seed "$DOT/espanso/match/base.yml"      "$HOME/.config/espanso/match/base.yml"
  seed "$DOT/espanso/config/default.yml"  "$HOME/.config/espanso/config/default.yml"
  seed "$DOT/copyq/copyq.conf"            "$HOME/.config/copyq/copyq.conf"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  seed "$DOT/ssh/config"                  "$HOME/.ssh/config" 600
  seed "$DOT/git/gitconfig"               "$HOME/.gitconfig"
  seed "$DOT/git/gitconfig-personal"      "$HOME/.gitconfig-personal"
  if grep -qE '@[A-Z_]+@' "$HOME/.gitconfig" "$HOME/.gitconfig-personal" 2>/dev/null; then
    warn "fill in the @NAME@/@EMAIL@ placeholders in ~/.gitconfig and ~/.gitconfig-personal"
  fi

  log "desktop launchers, default terminal list, helper scripts"
  mkdir -p "$HOME/.local/share/applications" "$HOME/.config/mac-parity-backup"
  for f in "$DOT"/applications/*.desktop; do
    sed "s|@HOME@|$HOME|g" "$f" > "$HOME/.local/share/applications/$(basename "$f")"
  done
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
  install -m 644 "$DOT/gnome/GNOME-xdg-terminals.list" "$HOME/.config/GNOME-xdg-terminals.list"
  install -m 755 "$DOT"/scripts/*.sh "$HOME/.config/mac-parity-backup/"

  log "tmux plugins, espanso service"
  [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] && "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null || true
  if have espanso; then espanso service register >/dev/null 2>&1 || true; fi

  log "charger connect/disconnect notifications (poweralertd user service)"
  install -D -m 644 "$DOT/power/poweralertd.service" "$HOME/.config/systemd/user/poweralertd.service"
  systemctl --user daemon-reload
  if [ -x "$HOME/.local/bin/poweralertd" ]; then
    systemctl --user enable --now poweralertd.service >/dev/null 2>&1 || warn "could not start poweralertd.service"
  else
    warn "poweralertd not built yet: run the 'tools' step, then 'configs' again"
  fi
}

# ---------------------------------------------------------------------------
step_gnome() {
  log "GNOME settings: dock, hot corners, shortcuts, touchpad, theme, fonts, wallpaper, terminal profile"
  sed "s|@HOME@|$HOME|g" "$DOT/gnome/desktop.dconf" | dconf load /
  info "log out and back in once so GNOME Shell loads the extensions and shell theme"
}

# ---------------------------------------------------------------------------
# Fingerprint login. When Ubuntu's libfprint doesn't know the reader (the HP 250R G10's Synaptics 06cb:0169
# first appears in 1.94.100), a pinned upstream release is built and ONLY its shared library goes into
# /usr/local, which the loader prefers over Ubuntu's copy. apt never updates it. Undo: scripts/revert-fingerprint.sh
FP_TAG=v1.94.100
FP_COMMIT=80a4b5ec612892c5c056c48dddaa561452cf37ec
FP_LIB=/usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2

fp_readers() { fprintd-list "$USER" 2>/dev/null | awk '/^found/ && $2 > 0 {print $2; exit}'; }

step_fingerprint() {
  sudo -v
  log "fingerprint reader for login, lock screen, sudo and password dialogs"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fprintd libpam-fprintd

  if [ "$(fp_readers)" ]; then
    info "reader already supported"
  else
    local src="$TMP/libfprint" supported match="" id
    git clone -q --depth 1 --branch "$FP_TAG" https://gitlab.freedesktop.org/libfprint/libfprint.git "$src"
    [ "$(git -C "$src" rev-parse HEAD)" = "$FP_COMMIT" ] || { warn "libfprint $FP_TAG is not the pinned commit"; exit 1; }

    # Build only if a plugged-in USB device is on this release's supported list.
    supported=$(sed '/^# Known unsupported/q' "$src/data/autosuspend.hwdb" | grep -oE '^usb:v[0-9A-F]{4}p[0-9A-F]{4}')
    for id in $(lsusb | awk '{print toupper($6)}'); do
      if grep -qx "usb:v${id%%:*}p${id##*:}" <<<"$supported"; then match="$id"; fi
    done
    if [ -z "$match" ]; then info "no fingerprint reader that libfprint $FP_TAG supports; skipping"; return; fi

    info "reader ${match,,} needs libfprint $FP_TAG: building it"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y meson ninja-build pkg-config \
      libglib2.0-dev libgusb-dev libgudev-1.0-dev libssl-dev libudev-dev libpixman-1-dev libcairo2-dev
    # The no-introspection test stubs iterate a dict with one variable, which meson 1.3 (Ubuntu 24.04) rejects.
    sed -i 's/foreach driver_test: drivers_tests$/foreach driver_test: drivers_tests.keys()/' "$src/tests/meson.build"
    meson setup "$src/build" "$src" --buildtype=release \
      -Ddoc=false -Dgtk-examples=false -Dintrospection=false -Dinstalled-tests=false >/dev/null
    ninja -C "$src/build" >/dev/null

    sudo install -D -m 644 "$src/build/libfprint/libfprint-2.so.2.0.0" "$FP_LIB.0.0"
    sudo ln -sfn libfprint-2.so.2.0.0 "$FP_LIB"
    sudo ldconfig
    sudo systemctl stop fprintd.service 2>/dev/null || true   # D-Bus starts it again with the new library
    if [ "$(fp_readers)" ]; then info "reader detected"
    else
      warn "reader still not detected; removing the /usr/local libfprint again"
      bash "$DOT/scripts/revert-fingerprint.sh"
      return
    fi
  fi

  # Ubuntu's profile waits 10 s for one try, which password dialogs often time out on. Same line, 30 s x 3.
  sudo install -m 644 "$DOT/pam/fprintd-local" /usr/share/pam-configs/fprintd-local
  sudo pam-auth-update --disable fprintd
  sudo pam-auth-update --enable fprintd-local
  info "add a finger in Settings -> System -> Users -> Fingerprint Login"
}

# ---------------------------------------------------------------------------
# Fan modes for HP laptops. The firmware fan curve can't be overridden (hp-wmi has no pwm1 duty value, and the
# 250R G10 ignores "full speed"), so Cool and Quiet lower CPU heat instead.
# Installs the root helper, a polkit policy that lets the active desktop user run it without a password,
# and a Quick Settings extension with Auto / Cool / Quiet. Skipped on other machines.
step_fan() {
  log "fan modes: Auto / Cool / Quiet in Quick Settings (HP hp-wmi only)"
  if ! grep -qsx hp /sys/class/hwmon/hwmon*/name || ! ls /sys/class/hwmon/hwmon*/pwm1_enable >/dev/null 2>&1; then
    info "no hp-wmi fan control on this machine; skipping"; return
  fi
  sudo -v
  sudo install -m 755 "$DOT/fan/fan-mode" /usr/local/sbin/fan-mode
  sudo install -m 644 "$DOT/fan/local.fan-mode.policy" /usr/share/polkit-1/actions/local.fan-mode.policy
  # fan-mode keeps its state in /run and the CPU limits are lost on reboot and resume, so a unit reapplies `cool`.
  sudo install -D -m 644 "$DOT/fan/fan-mode.service" /etc/systemd/system/fan-mode.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now fan-mode.service >/dev/null 2>&1 || warn "could not enable fan-mode.service"

  local uuid=fan-mode@quantumvik ext="$HOME/.local/share/gnome-shell/extensions/fan-mode@quantumvik" cur
  install -D -m 644 -t "$ext" "$DOT/fan/$uuid/metadata.json" "$DOT/fan/$uuid/extension.js"
  cur=$(gsettings get org.gnome.shell enabled-extensions)
  case "$cur" in
    *"$uuid"*) ;;
    "@as []") gsettings set org.gnome.shell enabled-extensions "['$uuid']" ;;
    *) gsettings set org.gnome.shell enabled-extensions "${cur%]}, '$uuid']" ;;
  esac
  info "$(/usr/local/sbin/fan-mode status); the Fan toggle appears after the next login"
}

# ---------------------------------------------------------------------------
main() {
  [ "$(id -u)" -ne 0 ] || { echo "Run as your normal user; the script calls sudo where it needs to."; exit 1; }
  local steps=("$@")
  [ ${#steps[@]} -gt 0 ] || steps=(packages tools desktop configs gnome fingerprint fan)
  for s in "${steps[@]}"; do
    case "$s" in
      packages|tools|desktop|configs|gnome|fingerprint|fan) "step_$s" ;;
      *) echo "Unknown step '$s'. Steps: packages tools desktop configs gnome fingerprint fan"; exit 1 ;;
    esac
  done
  log "done: ${steps[*]}"
}
main "$@"
