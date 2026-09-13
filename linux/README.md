# Linux desktop

Everything needed to rebuild my Ubuntu 24.04 (GNOME 46, Wayland) setup, which was
ported from a macOS machine. **No credentials live here** — see the bottom section.

```bash
git clone https://github.com/Quantum-vik/dotfiles.git ~/dotfiles
~/dotfiles/linux/install.sh                 # everything, in order
~/dotfiles/linux/install.sh configs gnome   # or just some steps
```

Then log out and back in once (GNOME loads new extensions and the shell theme only at login).

| Step | What it does |
|---|---|
| `packages` | Adds the VS Code, pgAdmin and Docker apt repos (signing keys checked against pinned fingerprints), installs `packages/apt.txt` plus Docker Engine (not Desktop) with you in the `docker` group, and Flathub apps from `packages/flatpak.txt`: Mission Center, ZapZap (WhatsApp), Teams for Linux |
| `tools` | Go, uv, lazygit, kubectl, AWS CLI, espanso (Wayland), Postman, poweralertd 0.3.0 (built from a pinned commit), Citrix Workspace app (optional App Protection/deviceTRUST/EPA off; Ubuntu root CAs linked into its store), Oh My Zsh + Powerlevel10k, tmux TPM; sets zsh as login shell and kitty as default terminal. Downloads are checksum-verified where the vendor publishes one |
| `desktop` | MesloLGS NF + Monocraft fonts, WhiteSur theme/icons/cursors, macOS-style dynamic wallpapers, kitty's background image, GNOME extensions from `packages/gnome-extensions.txt` |
| `configs` | Symlinks shell, kitty, tmux and Claude Code configs into this repo; seeds app configs that rewrite themselves; installs launchers and helper scripts |
| `gnome` | Loads `gnome/desktop.dconf` |
| `fingerprint` | Fingerprint for login, lock screen, `sudo` and password dialogs. If Ubuntu's libfprint doesn't recognise the reader but pinned upstream release 1.94.100 does, builds that release and installs only its library to `/usr/local`; skips machines without a supported reader. Waits 30 s per try, 3 tries (`pam/fprintd-local`; Ubuntu's default of 10 s often times out in password dialogs). Then add a finger in Settings → System → Users |
| `fan` | HP laptops only: a **Fan** toggle in Quick Settings with Auto / Cool / Quiet, switchable with no password (`fan/`). Skipped on other machines |

Every step is safe to re-run. A file that differs from the repo is moved to `<file>.bak-<timestamp>`.

## Layout

```
install.sh
packages/      apt.txt  flatpak.txt  gnome-extensions.txt
gnome/         desktop.dconf  GNOME-xdg-terminals.list
shell/         zshrc  zshenv  aliases.zsh  p10k.zsh        -> symlinked
kitty/         kitty.conf                                   -> symlinked
espanso/       match/base.yml  config/default.yml           -> seeded
copyq/         copyq.conf                                   -> seeded
git/           gitconfig  gitconfig-personal   (work identity global, personal under ~/WorkPersonal and ~/dotfiles)
ssh/           config          (host aliases only, no keys)
applications/  postman.desktop
pam/           fprintd-local   (fingerprint: 30 s per try, 3 tries)
fan/           fan-mode  local.fan-mode.policy  fan-mode@quantumvik/   (HP fan modes)
power/         poweralertd.service   (charger connect/disconnect notifications)
scripts/       revert-whitesur.sh  revert-ctrl-arrows.sh  revert-fingerprint.sh  verify-hot-corners.sh  citrix-latest.py
```

## Fingerprint reader (HP 250R G10)

Ubuntu 24.04's libfprint (1.94.7) doesn't include this laptop's Synaptics reader, `06cb:0169`. The `fingerprint`
step builds upstream `v1.94.100` (commit pinned in `install.sh`) and installs only
`/usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2`. The loader picks that path before Ubuntu's copy, and
Ubuntu's `fprintd` works with it unchanged.

- apt never updates this library. Once Ubuntu ships a libfprint that knows the reader, run
  `scripts/revert-fingerprint.sh` to go back to the packaged copy.
- Fingerprint doesn't unlock GNOME Keyring: after a fingerprint login, the first app that needs saved secrets
  asks for the password once.

## Fan modes (HP 250R G10)

The fan speed can't be set from Linux on this model. `hp-wmi` has no `pwm1` duty value and rejects manual
mode. It does accept "full speed" (`pwm1_enable=0`) and reads it back, but the embedded controller ignores
it. Measured under full CPU load in that mode: the CPU hit 96 °C, the fan waited 8 s, then ramped
1400 → 3800 RPM exactly as it does on auto. The firmware curve alone runs the single fan: off when cool,
up to ~3800 RPM under sustained load, and it stops around 48 °C.

The lever that does work is CPU heat. The `fan` step offers three modes, measured with a 25 s all-core load
(`openssl speed -multi 12 sha256`):

| Mode | CPU limits | Avg / peak temp | Power | Speed |
|---|---|---|---|---|
| Auto | stock (no sustained cap, 41 W bursts) | 96 / 99 °C | 29 W | 100 % |
| Cool | 15 W sustained, 20 W bursts, turbo on | 79 / 83 °C | 20 W | 82 % |
| Quiet | 10 W, turbo off | 52 / 54 °C | 6 W | 31 % |

A cap only takes effect while the CPU would otherwise draw more than it (heavy work such as builds or Docker).

- `/usr/local/sbin/fan-mode status|auto|cool|quiet` does the work, and also runs from a terminal with `pkexec`.
  Its polkit policy lets the person at the laptop run it with no password.
- The Quick Settings extension calls it. The top-bar fan icon shows only when the mode isn't Auto.
- Nothing survives a reboot: fan, turbo and power limits all come back as Auto.

## What `desktop.dconf` sets

- **Touchpad**: tap-to-click, natural scrolling, two-finger right click. Mouse keeps traditional scroll.
- **Keyboard**: 225 ms repeat delay, US + India layouts, `Ctrl+Space` freed from IBus for editors.
- **Workspaces**: fixed 4; `Ctrl+←/→` switch, `Ctrl+Shift+←/→` move a window (this takes over word-jump).
- **Dock**: right edge, autohide, 64 px.
- **Hot corners** (Custom Hot Corners – Extended): top-left lock, top-right overview, bottom-left app grid, bottom-right Quick Note (`zim`).
- **Shortcuts**: `Super+V` CopyQ, `Super+L` lock, `Shift+Super+3/4/5/6` screenshots and recording, message tray on `Super+M`.
- **Look**: WhiteSur-Dark, window buttons on the left, Inter 10.5, Sonoma time-of-day wallpaper, weekday + battery % in the top bar, Night Light off.
- **Top bar system monitor**: Astra Monitor (the macOS Stats equivalent) with live CPU, memory, disk, network
  and CPU-temperature graphs; click any of them for history and top processes. Per-process network/disk
  views ask for your password via pkexec (nethogs/iotop). No GPU module: Astra only supports AMD/NVIDIA.
- **GNOME Terminal**: MesloLGS NF, matching dark palette, opaque.
- **Charger notifications**: [poweralertd](https://sr.ht/~kennylevinsen/poweralertd) runs as a user service
  (`power/poweralertd.service`) with `-S -i battery`, so it only says *Power supply online/offline*: once at login, then
  on every change. Don't add `-s`: poweralertd then never finishes connecting to the session bus, which drops it, and
  the first charger event crashes it. Ubuntu packages 0.2.0, which has no options and also announces every battery
  state and Bluetooth device, so `tools` builds 0.3.0.
- **Reopen apps after logout/restart**: [Another Window Session Manager](https://github.com/nlpsuge/gnome-shell-extension-another-window-session-manager)
  saves the open apps and windows when you log out, restart or power off, and reopens them at the next login
  without asking, back on their workspaces at their size and position. Apps restore their own contents only if
  they keep them (VS Code does; Chrome needs *Settings → On startup → Continue where you left off*).

Not portable as-is: the hot-corner keys are for monitor 0 only.

## tmux across logouts and reboots

The tmux server keeps running through a GNOME logout, so its sessions are still there, just detached.
`tmux` / `tm` with no arguments (`shell/aliases.zsh`) therefore reattaches to the most recent session instead of
creating an empty one. After a reboot there is no server: `tmux` starts one, and tmux-continuum restores the last
tmux-resurrect save (every 5 minutes, `tmux/tmux.conf`). Pick another session with `prefix s`.

## Deliberately not in this repo

Restore these by hand. Never commit them here; this repo is public.

| What | Where it lives |
|---|---|
| SSH private keys | `~/.ssh/*_github` — generate new ones and add them to GitHub |
| Kubernetes configs | `~/.kube/` (contain client certificates) |
| AWS credentials | `~/.aws/credentials` and `~/.aws/config` |
| Postgres passwords | `~/.pgpass` |
| pgAdmin server list | `~/.pgadmin/pgadmin4.db` (re-add servers in the app) |
| GitHub CLI login | `gh auth login` |
| VS Code settings and extensions | Settings Sync (sign in inside VS Code) |
| CopyQ clipboard history | never synced |
