# Omarchy

Rebuilds this machine's setup on [Omarchy](https://omarchy.org) 4 (Arch Linux + Hyprland). Omarchy keeps its own
theme, top bar, launcher, notifications and lock screen. This adds my apps, shell, terminal and tmux, and brings over
the GNOME habits from the Ubuntu machine where they don't fight Omarchy's own keys. **No credentials live here.**

```bash
git clone https://github.com/Quantum-vik/dotfiles.git ~/dotfiles
~/dotfiles/omarchy/install.sh                     # everything, in order
~/dotfiles/omarchy/install.sh configs hyprland    # or just some steps
```

Then reboot once: the login shell, the Docker group and poweralertd all start clean after it.

| Step | What it does |
|---|---|
| `packages` | `packages/pacman.txt` (Arch and Omarchy repositories), `packages/aur.txt` (Chrome, pgAdmin, espanso, Citrix Workspace), the Flathub apps from `../linux/packages/flatpak.txt`, and Docker without sudo through Omarchy's own prompt |
| `tools` | Postman, poweralertd 0.3.0 (pinned commit), Oh My Zsh + Powerlevel10k, tmux TPM; sets zsh as login shell, kitty as the terminal for Super+Return, Chrome as default browser; tells VS Code to use GNOME Keyring; lets Citrix trust Arch's root certificates |
| `desktop` | MesloLGS NF + Monocraft fonts, and kitty's Sonoma background image (checksum-pinned) |
| `configs` | Symlinks shell, kitty, tmux and Claude Code configs; seeds git, ssh and espanso configs; Postman launcher; charger notifications |
| `hyprland` | Links `hypr/input.lua` and `hypr/bindings.lua` over Omarchy's empty override files |
| `fingerprint` | Runs Omarchy's fingerprint setup (sudo, password dialogs, lock screen). Its `libfprint-git` knows this laptop's reader, so nothing is built by hand |
| `fan` | HP laptops only: the Ubuntu fan helper and polkit policy, switched from **Omarchy menu → Setup → Fan** |

Every step is safe to re-run. A file that differs from the repo is moved to `<file>.bak-<timestamp>`.

Shared with the Ubuntu setup, so a change in one place applies to both: `linux/shell/`, `linux/kitty/`, `tmux/`,
`claude/`, `linux/git/`, `linux/ssh/`, `linux/espanso/`, `linux/applications/`, `linux/power/`, `linux/fan/`.

## Layout

```
install.sh
packages/  pacman.txt  aur.txt
hypr/      input.lua  bindings.lua        -> ~/.config/hypr/ (loaded after Omarchy's defaults)
menu/      omarchy-menu.jsonc             -> ~/.config/omarchy/extensions/ (Setup -> Fan)
```

## Differences from the Ubuntu desktop

| On Ubuntu (GNOME) | On Omarchy |
|---|---|
| US + India layouts, switched with Super+Space | Same layouts, switched with **Left Alt + Right Alt** (Super+Space is Omarchy's menu) |
| 225 ms key repeat, natural scrolling and tap-to-click on the touchpad, traditional mouse wheel | Same |
| Ctrl+←/→ switches workspace, Ctrl+Shift+←/→ moves the window, 4 workspaces | Same, stopping at 1 and 4. Super+1…9 still reach the others |
| Super+L locks | Same. Omarchy's workspace layout toggle moves to **Super+Alt+L** |
| Super+V opens CopyQ | Super+V opens Omarchy's clipboard history. CopyQ isn't installed. Omarchy's "universal paste" on Super+V is gone; Ctrl+V pastes |
| Shift+Super+3/4/5 screenshots | **Print** (Omarchy's). Super+Shift+number moves windows between workspaces there |
| Fan toggle in Quick Settings | Omarchy menu → Setup → Fan (Auto / Cool / Quiet), same helper, no password |
| Fingerprint also at the login screen | sudo, password dialogs and lock screen. The login screen asks for the password |
| Charger notifications (poweralertd) | Same |
| tmux sessions come back after logout and reboot | Same. Omarchy's own `~/.config/tmux/tmux.conf` is moved aside, because tmux would load it on top of this repo's config |
| Apps reopen after logout (Another Window Session Manager) | Nothing equivalent on Hyprland |
| Dock, hot corners, Astra Monitor in the top bar | None. Apps: Super+Alt+Space. Activity: Super+Ctrl+T (btop) or Mission Center |
| WhiteSur theme, Sonoma wallpapers | Omarchy's themes. kitty keeps its own colours and Sonoma background, so switching Omarchy's theme doesn't restyle kitty |
| Docker group added directly | Omarchy's `omarchy-setup-security-sudoless-docker` explains the risk and asks first |

zsh replaces Omarchy's bash, so Omarchy's bash aliases and starship prompt aren't used. `linux/shell/zshrc`
activates mise, which Omarchy uses to install `claude` and `gh`.

## AUR packages

`packages/aur.txt` lists Chrome, pgAdmin, espanso and Citrix Workspace. On Ubuntu these come from signed vendor
repositories or checksum-verified downloads. On Arch they come from AUR build scripts, which individual volunteers
maintain and yay runs without showing them. Read one before the first install with `yay -Gp <name>`.

## Status

Written against Omarchy 4.0.3 (September 2026) and not yet run on a real Omarchy install. What was checked:

- Every package name exists in Arch's, Omarchy's or the AUR repositories.
- Hyprland 0.56.2 `--verify-config` accepts `hypr/*.lua` loaded with Omarchy's defaults.
- The `configs` and `hyprland` steps ran twice in an Arch container.
- poweralertd builds on Arch.

## Deliberately not in this repo

The same credentials as on Ubuntu: SSH keys, `~/.kube`, `~/.aws`, `~/.pgpass`, pgAdmin servers, `gh auth login`,
VS Code Settings Sync. See [`../linux/README.md`](../linux/README.md#deliberately-not-in-this-repo). Project folders,
Docker images and browser profiles aren't dotfiles either: copy them over separately.
