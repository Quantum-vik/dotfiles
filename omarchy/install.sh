#!/usr/bin/env bash
# Rebuild this machine's setup on Omarchy 4 (Arch Linux + Hyprland). Counterpart of ../linux/install.sh.
#
#   ./install.sh                     run every step, in order
#   ./install.sh configs hyprland    run only the named steps
#
# Steps: packages  tools  desktop  configs  hyprland  plugins  fingerprint  fan
#
# App configs (shell, tmux, git, ssh, espanso, Claude Code, fan helper, poweralertd unit) are the same files
# ../linux/install.sh uses, so both machines stay in sync. Omarchy keeps its own theme, bar and launcher, and kitty
# gets its own config here (kitty/kitty.conf) so it follows that theme.
# Safe to re-run: each step skips work that is already done, and any existing file that differs from the
# repo is moved to <file>.bak-<timestamp>, never deleted.
# This script contains no credentials. See README.md for what to restore by hand.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"     # .../dotfiles/omarchy
REPO="$(dirname "$DOT")"                                # .../dotfiles
LNX="$REPO/linux"                                       # configs shared with the Ubuntu setup
TS="$(date +%Y%m%d-%H%M%S)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
list() { grep -vE '^\s*(#|$)' "$1"; }

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

  log "Arch packages ($(list "$DOT/packages/pacman.txt" | wc -l), from Arch's and Omarchy's repositories)"
  # shellcheck disable=SC2046
  omarchy-pkg-add $(list "$DOT/packages/pacman.txt")

  log "AUR packages: $(list "$DOT/packages/aur.txt" | tr '\n' ' ')"
  info "AUR build scripts are written by individual maintainers and yay installs them unreviewed; see README.md"
  # shellcheck disable=SC2046
  omarchy-pkg-aur-add $(list "$DOT/packages/aur.txt")

  log "Flathub apps (the Ubuntu list)"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  list "$LNX/packages/flatpak.txt" | xargs -r flatpak install --user -y --noninteractive flathub

  log "Docker without sudo, as on Ubuntu (Omarchy leaves it off because the docker group is root-equivalent)"
  # Omarchy's own command: it explains the risk, asks, and records that a reboot is needed.
  OMARCHY_DEFER_REBOOT=1 omarchy-setup-security-sudoless-docker
}

# ---------------------------------------------------------------------------
step_tools() {
  sudo -v
  mkdir -p "$HOME/.local/bin"

  log "Postman (official tarball in ~/.local/share so its self-updater works)"
  if [ -x "$HOME/.local/share/Postman/Postman" ]; then info "present"; else
    curl -fsSL https://dl.pstmn.io/download/latest/linux_64 -o "$TMP/postman.tgz"
    mkdir -p "$HOME/.local/share/Postman"
    tar xzf "$TMP/postman.tgz" -C "$HOME/.local/share/Postman" --strip-components=1
    ln -sf "$HOME/.local/share/Postman/Postman" "$HOME/.local/bin/postman"
  fi

  log "poweralertd 0.3.0 (charger notifications; only in the AUR, so built from the same pinned commit as Ubuntu)"
  if [ -x "$HOME/.local/bin/poweralertd" ]; then info "present"; else
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

  log "login shell -> zsh, default terminal -> kitty (Super+Return), default browser -> Chrome"
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo chsh -s "$(command -v zsh)" "$USER"
  omarchy-install-terminal kitty
  if [ -f /usr/share/applications/google-chrome.desktop ]; then
    # Omarchy's bash exports BROWSER, and xdg-settings refuses to change the default while it is set.
    env -u BROWSER xdg-settings set default-web-browser google-chrome.desktop
  else
    warn "Chrome not installed yet: run the 'packages' step, then 'tools' again"
  fi

  log "VS Code: keep the Settings Sync login in GNOME Keyring (VS Code can't detect a keyring under Hyprland)"
  if [ ! -e "$HOME/.vscode/argv.json" ]; then
    mkdir -p "$HOME/.vscode"
    printf '{\n  "password-store": "gnome-libsecret"\n}\n' > "$HOME/.vscode/argv.json"
    info "wrote ~/.vscode/argv.json"
  elif ! grep -q '"password-store"' "$HOME/.vscode/argv.json"; then
    warn "add \"password-store\": \"gnome-libsecret\" to ~/.vscode/argv.json, then restart VS Code"
  else
    info "argv.json already sets password-store"
  fi
  # Omarchy writes each theme's editor theme into VS Code's settings.json on every theme change, which replaced the
  # Hyper theme Settings Sync brings from the Mac. This flag file is Omarchy's own opt-out.
  if [ -e "$HOME/.local/state/omarchy/toggles/skip-vscode-theme-changes" ]; then
    info "Omarchy already leaves the VS Code theme alone"
  else
    mkdir -p "$HOME/.local/state/omarchy/toggles"
    touch "$HOME/.local/state/omarchy/toggles/skip-vscode-theme-changes"
    info "Omarchy theme changes no longer touch the VS Code theme"
  fi

  if [ -d /opt/Citrix/ICAClient/keystore/cacerts ]; then
    log "Citrix: trusting Arch's root certificates (prevents SSL error 61)"
    for c in /etc/ca-certificates/extracted/cadir/*.pem; do
      d="/opt/Citrix/ICAClient/keystore/cacerts/$(basename "$c")"; [ -e "$d" ] || sudo ln -s "$c" "$d"
    done
    sudo /opt/Citrix/ICAClient/util/ctx_rehash /opt/Citrix/ICAClient/keystore/cacerts >/dev/null 2>&1 || true
  fi

  log "Cloudflare WARP, on at every boot (the ISP's route to Fastly, which serves PyPI, GitHub and Flathub, is slow)"
  if have warp-cli; then
    sudo systemctl enable --now warp-svc.service
    for _ in $(seq 1 15); do warp-cli --accept-tos status >/dev/null 2>&1 && break; sleep 1; done
    warp-cli --accept-tos registration show 2>/dev/null | grep -q '^Device ID' \
      || warp-cli --accept-tos registration new >/dev/null
    warp-cli --accept-tos mode warp >/dev/null
    warp-cli --accept-tos connect >/dev/null   # also sets Always On, so it reconnects after every reboot
    info "$(warp-cli --accept-tos status | head -1)"
    # If Cloudflare stops passing traffic, warp-fallback switches to the normal connection and retries WARP later.
    link "$DOT/warp/warp-fallback" "$HOME/.local/bin/warp-fallback"
    for u in warp-fallback.service warp-fallback.timer; do
      install -D -m 644 "$DOT/warp/$u" "$HOME/.config/systemd/user/$u"
    done
    systemctl --user daemon-reload
    systemctl --user enable --now warp-fallback.timer >/dev/null 2>&1 && info "warp-fallback checks every minute"
  else
    warn "WARP not installed yet: run the 'packages' step, then 'tools' again"
  fi
}

# ---------------------------------------------------------------------------
step_desktop() {
  local fonts="$HOME/.local/share/fonts"

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
}

# ---------------------------------------------------------------------------
step_configs() {
  log "symlinked configs (shared with the Ubuntu setup; editing them edits this repo)"
  link "$LNX/shell/zshrc"        "$HOME/.zshrc"
  link "$LNX/shell/zshenv"       "$HOME/.zshenv"
  link "$LNX/shell/p10k.zsh"     "$HOME/.p10k.zsh"
  if [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
    link "$LNX/shell/aliases.zsh" "$HOME/.oh-my-zsh/custom/aliases.zsh"
  else
    warn "Oh My Zsh not installed yet: run the 'tools' step, then 'configs' again for aliases.zsh"
  fi
  link "$DOT/kitty/kitty.conf"   "$HOME/.config/kitty/kitty.conf"
  link "$DOT/kitty/open-actions.conf" "$HOME/.config/kitty/open-actions.conf"
  link "$DOT/kitty/kitty-open-clicked-word" "$HOME/.local/bin/kitty-open-clicked-word"
  for f in settings.json keybindings.json statusline.sh CLAUDE.md; do link "$REPO/claude/$f" "$HOME/.claude/$f"; done
  link "$REPO/claude/claude-session-name" "$HOME/.local/bin/claude-session-name"

  log "tmux: this repo's config replaces Omarchy's"
  # tmux reads ~/.tmux.conf AND ~/.config/tmux/tmux.conf when both exist, so Omarchy's file (Ctrl+Space prefix,
  # its own splits and status bar) would be applied on top of this one. Re-run this step if an update restores it.
  if [ -e "$HOME/.config/tmux/tmux.conf" ] || [ -L "$HOME/.config/tmux/tmux.conf" ]; then
    mv "$HOME/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf.bak-$TS"
    warn "moved Omarchy's ~/.config/tmux/tmux.conf -> .bak-$TS"
  fi
  link "$REPO/tmux/tmux.conf"    "$HOME/.tmux.conf"

  log "seeded configs (written only if missing; these apps rewrite their own files)"
  seed "$LNX/espanso/match/base.yml"      "$HOME/.config/espanso/match/base.yml"
  seed "$LNX/espanso/config/default.yml"  "$HOME/.config/espanso/config/default.yml"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  seed "$LNX/ssh/config"                  "$HOME/.ssh/config" 600
  seed "$LNX/git/gitconfig"               "$HOME/.gitconfig"
  seed "$LNX/git/gitconfig-personal"      "$HOME/.gitconfig-personal"
  if grep -qE '@[A-Z_]+@' "$HOME/.gitconfig" "$HOME/.gitconfig-personal" 2>/dev/null; then
    warn "fill in the @NAME@/@EMAIL@ placeholders in ~/.gitconfig and ~/.gitconfig-personal"
  fi

  log "desktop launchers"
  mkdir -p "$HOME/.local/share/applications"
  for f in "$LNX"/applications/*.desktop; do
    sed "s|@HOME@|$HOME|g" "$f" > "$HOME/.local/share/applications/$(basename "$f")"
  done
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  log "tmux plugins, espanso service"
  [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] && "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null || true
  if have espanso; then espanso service register >/dev/null 2>&1 || true; fi

  log "charger connect/disconnect notifications (poweralertd user service)"
  install -D -m 644 "$LNX/power/poweralertd.service" "$HOME/.config/systemd/user/poweralertd.service"
  systemctl --user daemon-reload
  if [ -x "$HOME/.local/bin/poweralertd" ]; then
    systemctl --user enable --now poweralertd.service >/dev/null 2>&1 || warn "could not start poweralertd.service"
  else
    warn "poweralertd not built yet: run the 'tools' step, then 'configs' again"
  fi
}

# ---------------------------------------------------------------------------
step_hyprland() {
  log "Hyprland: keyboard, touchpad, GNOME-style shortcuts, blur and cursor size (loaded after Omarchy's defaults)"
  link "$DOT/hypr/input.lua"     "$HOME/.config/hypr/input.lua"
  link "$DOT/hypr/bindings.lua"  "$HOME/.config/hypr/bindings.lua"
  link "$DOT/hypr/looknfeel.lua" "$HOME/.config/hypr/looknfeel.lua"
  # GTK apps take the cursor size from gsettings, not XCURSOR_SIZE; keep it equal to looknfeel.lua.
  gsettings set org.gnome.desktop.interface cursor-size 18 2>/dev/null && info "GTK cursor size 18"
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl; then
    hyprctl reload >/dev/null && info "Hyprland reloaded; a config error shows as a banner at the top of the screen"
    hyprctl setcursor "$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")" 18 >/dev/null 2>&1 || true
  else
    info "takes effect at the next Hyprland login"
  fi
}

# ---------------------------------------------------------------------------
# Shell plugins from plugins/plugins.txt, then the bar layout from plugins/bar.json. Plugins run unsandboxed inside
# omarchy-shell, so each line pins the commit that was read before install; a newer upstream commit gets a warning.
step_plugins() {
  local dir="$HOME/.config/omarchy/plugins" shell="$HOME/.config/omarchy/shell.json" id url commit head

  log "Omarchy shell plugins ($(list "$DOT/plugins/plugins.txt" | wc -l), see plugins/plugins.txt)"
  while read -r id url commit; do
    if [ -d "$dir/$id/.git" ]; then
      info "present  $id"
    elif omarchy plugin add "$url" --enable --yes >/dev/null 2>&1; then
      info "added    $id"
    else
      warn "could not add $id from $url"; continue
    fi
    head=$(git -C "$dir/$id" rev-parse HEAD 2>/dev/null)
    [ "$head" = "$commit" ] \
      || warn "$id is at ${head:0:7}, not the reviewed ${commit:0:7}; read: git -C ${dir/#$HOME/\~}/$id log -p ${commit:0:7}..HEAD"
  done < <(list "$DOT/plugins/plugins.txt")

  # hyprmoncfgd (packages/aur.txt) switches off Omarchy's monitor watcher, which handles clamshell mode and lost
  # displays, as soon as it starts, even with no profile to apply in its place. So it starts only once one is saved.
  if have hyprmoncfgd; then
    if compgen -G "$HOME/.config/hyprmoncfg/profiles/*" >/dev/null; then
      systemctl --user enable --now hyprmoncfgd.service >/dev/null 2>&1 && info "hyprmoncfgd running" \
        || warn "could not start hyprmoncfgd.service"
    else
      info "hyprmoncfgd off: save a monitor profile with 'hyprmoncfg', then: systemctl --user enable --now hyprmoncfgd"
    fi
  fi

  log "bar layout (plugins/bar.json), so the plugin widgets fit beside the clock"
  if [ -f "$shell" ] && jq -e --slurpfile bar "$DOT/plugins/bar.json" '.bar == $bar[0]' "$shell" >/dev/null; then
    info "ok       bar layout"; return
  fi
  if [ -f "$shell" ]; then
    cp "$shell" "$shell.bak-$TS"; warn "backed up ~/.config/omarchy/shell.json -> .bak-$TS"
  else
    mkdir -p "$(dirname "$shell")"; echo '{}' > "$shell"
  fi
  jq --slurpfile bar "$DOT/plugins/bar.json" '.bar = $bar[0]' "$shell" > "$TMP/shell.json" && mv "$TMP/shell.json" "$shell"
  omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
  info "applied  bar layout"
}

# ---------------------------------------------------------------------------
# Omarchy's own setup covers this: it installs libfprint-git (1.94.100+, which knows the HP 250R G10's Synaptics
# 06cb:0169), enrolls a finger, then adds fingerprint to sudo, polkit and the lock screen. pam_fprintd's
# defaults already wait 30 s per try with 3 tries, the timing linux/pam/fprintd-local sets on Ubuntu.
step_fingerprint() {
  log "fingerprint for sudo, password dialogs and the lock screen"
  if [ -f /etc/pam.d/omarchy-lock-fingerprint ]; then info "already set up"; return; fi
  if ! omarchy-hw-fingerprint; then info "no fingerprint reader on this machine; skipping"; return; fi
  omarchy-setup-security-fingerprint || warn "fingerprint setup failed; retry from Omarchy menu -> Setup -> Security"
}

# ---------------------------------------------------------------------------
# Fan modes for HP laptops, as on Ubuntu (see linux/README.md "Fan modes"): the same root helper and polkit policy,
# with an Omarchy menu entry instead of the GNOME Quick Settings toggle. Skipped on other machines.
step_fan() {
  log "fan modes: Auto / Cool / Quiet in the Omarchy menu (HP hp-wmi only)"
  if ! grep -qsx hp /sys/class/hwmon/hwmon*/name || ! ls /sys/class/hwmon/hwmon*/pwm1_enable >/dev/null 2>&1; then
    info "no hp-wmi fan control on this machine; skipping"; return
  fi
  sudo -v
  sudo install -D -m 755 "$LNX/fan/fan-mode" /usr/local/sbin/fan-mode
  sudo install -D -m 644 "$LNX/fan/local.fan-mode.policy" /usr/share/polkit-1/actions/local.fan-mode.policy
  # fan-mode keeps its state in /run and the CPU limits are lost on reboot and resume, so a unit reapplies `cool`.
  sudo install -D -m 644 "$LNX/fan/fan-mode.service" /etc/systemd/system/fan-mode.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now fan-mode.service >/dev/null 2>&1 || warn "could not enable fan-mode.service"
  link "$DOT/menu/omarchy-menu.jsonc" "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
  info "$(/usr/local/sbin/fan-mode status); switch it in Omarchy menu (Super+Space) -> Setup -> Fan"
}

# ---------------------------------------------------------------------------
# Voice dictation: hold F9 (or toggle with Super+Ctrl+X) and the transcript types itself in at the cursor.
# Omarchy ships the keybindings (default/hypr/bindings/voxtype.lua) and offers the install from its menu; this
# step does the same unattended. Everything runs locally -- whisper.cpp against a model in ~/.local/share/voxtype,
# no audio leaves the machine -- so the first run downloads ~150 MB. voxtype rewrites config.toml when it migrates
# settings between versions, so the config is seeded rather than linked; copy it back here after changing it.
step_dictation() {
  log "voice dictation (voxtype)"
  have voxtype || { info "voxtype-bin not installed; run the packages step first"; return; }
  seed "$DOT/voxtype/config.toml" "$HOME/.config/voxtype/config.toml"
  voxtype setup --download --no-post-install --quiet || warn "model download failed"
  # The pre-built Vulkan backend is already on disk; enabling it just repoints /usr/bin/voxtype at it, which is
  # why this needs root. On the HP 250R G10 it moves transcription onto the Raptor Lake iGPU.
  if omarchy-hw-vulkan && [ "$(readlink -f /usr/bin/voxtype)" != /usr/lib/voxtype/voxtype-vulkan ]; then
    sudo -v
    sudo voxtype setup gpu --enable >/dev/null || warn "could not switch voxtype to the Vulkan backend"
  fi
  voxtype setup systemd >/dev/null 2>&1 || true
  systemctl --user restart voxtype 2>/dev/null || warn "voxtype.service did not restart"
  # `voxtype setup gpu --status` writes straight to the terminal, so read the symlink it switches instead.
  info "backend $(basename "$(readlink -f /usr/bin/voxtype)" | sed s/^voxtype-//); hold F9 to dictate"
}

# ---------------------------------------------------------------------------
# Wallpapers, per theme, from backgrounds/<theme>/. Omarchy reads ~/.config/omarchy/backgrounds/<theme> as the
# user's own background folder for that theme, alongside the ones the theme ships, and cycles all of them with
# omarchy-theme-bg-next. The images live in this repo; backgrounds/<theme>.txt records where each came from and
# what was done to it. Linked rather than copied, so a wallpaper dropped into the repo shows up without rerunning
# this, and one saved into the folder by hand is a file this repo does not own.
step_backgrounds() {
  local dir theme dest image
  for dir in "$DOT"/backgrounds/*/; do
    [ -d "$dir" ] || continue
    theme="$(basename "$dir")"
    dest="$HOME/.config/omarchy/backgrounds/$theme"
    log "backgrounds for the $theme theme ($(find "$dir" -type f | wc -l) images, $(du -sh "$dir" | cut -f1))"
    mkdir -p "$dest"
    for image in "$dir"*; do
      [ -f "$image" ] || continue
      link "$image" "$dest/$(basename "$image")"
    done
  done
  info "switch backgrounds with omarchy-theme-bg-next, or omarchy-theme-bg-set <path>"
}

# ---------------------------------------------------------------------------
main() {
  [ "$(id -u)" -ne 0 ] || { echo "Run as your normal user; the script calls sudo where it needs to."; exit 1; }
  have omarchy-pkg-add || { echo "This installer is for Omarchy. On Ubuntu use ../linux/install.sh."; exit 1; }
  local steps=("$@")
  [ ${#steps[@]} -gt 0 ] || steps=(packages tools desktop configs hyprland plugins fingerprint fan dictation backgrounds)
  for s in "${steps[@]}"; do
    case "$s" in
      packages|tools|desktop|configs|hyprland|plugins|fingerprint|fan|dictation|backgrounds) "step_$s" ;;
      *) echo "Unknown step '$s'. Steps: packages tools desktop configs hyprland plugins fingerprint fan dictation backgrounds"; exit 1 ;;
    esac
  done
  log "done: ${steps[*]}"
}
main "$@"
