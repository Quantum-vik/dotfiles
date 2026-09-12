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
| `packages` | Adds the VS Code, pgAdmin and Docker apt repos (signing keys checked against pinned fingerprints), installs `packages/apt.txt` plus Docker Engine (not Desktop) with you in the `docker` group, and Flathub apps from `packages/flatpak.txt` |
| `tools` | Go, uv, lazygit, kubectl, AWS CLI, espanso (Wayland), Postman, Oh My Zsh + Powerlevel10k, tmux TPM; sets zsh as login shell and kitty as default terminal. Downloads are checksum-verified where the vendor publishes one |
| `desktop` | MesloLGS NF + Monocraft fonts, WhiteSur theme/icons/cursors, macOS-style dynamic wallpapers, kitty's background image, GNOME extensions from `packages/gnome-extensions.txt` |
| `configs` | Symlinks shell, kitty, tmux and Claude Code configs into this repo; seeds app configs that rewrite themselves; installs launchers and helper scripts |
| `gnome` | Loads `gnome/desktop.dconf` |

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
applications/  whatsapp-web  teams-web  postman  .desktop
scripts/       revert-whitesur.sh  revert-ctrl-arrows.sh  verify-hot-corners.sh
```

## What `desktop.dconf` sets

- **Touchpad**: tap-to-click, natural scrolling, two-finger right click. Mouse keeps traditional scroll.
- **Keyboard**: 225 ms repeat delay, US + India layouts, `Ctrl+Space` freed from IBus for editors.
- **Workspaces**: fixed 4; `Ctrl+←/→` switch, `Ctrl+Shift+←/→` move a window (this takes over word-jump).
- **Dock**: right edge, autohide, 64 px.
- **Hot corners** (Custom Hot Corners – Extended): top-left lock, top-right overview, bottom-left app grid, bottom-right Quick Note (`zim`).
- **Shortcuts**: `Super+V` CopyQ, `Super+L` lock, `Shift+Super+3/4/5/6` screenshots and recording, message tray on `Super+M`.
- **Look**: WhiteSur-Dark, window buttons on the left, Inter 10.5, Sonoma time-of-day wallpaper, weekday + battery % in the top bar, Vitals, Night Light off.
- **GNOME Terminal**: MesloLGS NF, matching dark palette, opaque.

Not portable as-is: the hot-corner keys are for monitor 0 only.

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
