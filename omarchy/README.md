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
| `packages` | `packages/pacman.txt` (Arch and Omarchy repositories), `packages/aur.txt` (Chrome, pgAdmin, espanso, Citrix Workspace, Cloudflare WARP), the Flathub apps from `../linux/packages/flatpak.txt`, and Docker without sudo through Omarchy's own prompt |
| `tools` | Postman, poweralertd 0.3.0 (pinned commit), Oh My Zsh + Powerlevel10k, tmux TPM; sets zsh as login shell, kitty as the terminal for Super+Return, Chrome as default browser; tells VS Code to use GNOME Keyring and stops Omarchy theme changes from replacing its color theme; lets Citrix trust Arch's root certificates; turns Cloudflare WARP on at every boot, with a fallback to the normal connection |
| `desktop` | MesloLGS NF + Monocraft fonts |
| `configs` | Symlinks shell, tmux and Claude Code configs, and the Omarchy kitty config; seeds git, ssh and espanso configs; Postman launcher; charger notifications |
| `hyprland` | Links `hypr/input.lua`, `hypr/bindings.lua` and `hypr/looknfeel.lua` (blur on, no gaps, cursor size 18) over Omarchy's empty override files; sets GTK's cursor size to match |
| `plugins` | Installs the shell plugins in `plugins/plugins.txt` and applies the bar layout in `plugins/bar.json`; warns when a plugin's code is newer than the reviewed commit |
| `fingerprint` | Runs Omarchy's fingerprint setup (sudo, password dialogs, lock screen). Its `libfprint-git` knows this laptop's reader, so nothing is built by hand |
| `fan` | HP laptops only: the Ubuntu fan helper and polkit policy, switched from **Omarchy menu → Setup → Fan** |

Every step is safe to re-run. A file that differs from the repo is moved to `<file>.bak-<timestamp>`.

Shared with the Ubuntu setup, so a change in one place applies to both: `linux/shell/`, `tmux/`,
`claude/`, `linux/git/`, `linux/ssh/`, `linux/espanso/`, `linux/applications/`, `linux/power/`, `linux/fan/`.

## Layout

```
install.sh
packages/  pacman.txt  aur.txt
hypr/      input.lua  bindings.lua  looknfeel.lua  -> ~/.config/hypr/ (loaded after Omarchy's defaults)
kitty/     kitty.conf                              -> ~/.config/kitty/ (follows the Omarchy theme)
warp/      warp-fallback  .service  .timer         -> ~/.local/bin, ~/.config/systemd/user/ (WARP fallback)
plugins/   plugins.txt  bar.json                   -> ~/.config/omarchy/plugins/, the bar in ~/.config/omarchy/shell.json
menu/      omarchy-menu.jsonc                      -> ~/.config/omarchy/extensions/ (Setup -> Fan)
```

## Differences from the Ubuntu desktop

| On Ubuntu (GNOME) | On Omarchy |
|---|---|
| US + India layouts, switched with Super+Space | Same layouts, switched with **Left Alt + Right Alt** (Super+Space is Omarchy's menu) |
| 225 ms key repeat, natural scrolling and tap-to-click on the touchpad, traditional mouse wheel | Same |
| Ctrl+←/→ switches workspace, Ctrl+Shift+←/→ moves the window, 4 workspaces | Same, four to a screen. Hyprland numbers workspaces across the whole desktop, so each monitor owns a band by position: leftmost 1–4, next 5–8. Stepping stays on the screen holding focus and pulls its own workspace back if that workspace is showing elsewhere. Super+1…9 still reach any of them |
| Super+L locks | Same. Omarchy's workspace layout toggle moves to **Super+Alt+L** |
| Super+V opens CopyQ | Super+V opens Omarchy's clipboard history. CopyQ isn't installed. Omarchy's "universal paste" on Super+V is gone; Ctrl+V pastes |
| Shift+Super+3/4/5 screenshots | **Print** (Omarchy's) or **Alt+Shift+4**, like Cmd+Shift+4 on the Mac. Super+Shift+number moves windows between workspaces there |
| Fan toggle in Quick Settings | Omarchy menu → Setup → Fan (Auto / Cool / Quiet), same helper, no password |
| Fingerprint also at the login screen | sudo, password dialogs and lock screen. The login screen asks for the password |
| Charger notifications (poweralertd) | Same |
| tmux sessions come back after logout and reboot | Same. Omarchy's own `~/.config/tmux/tmux.conf` is moved aside, because tmux would load it on top of this repo's config |
| Apps reopen after logout (Another Window Session Manager) | Nothing equivalent on Hyprland |
| Dock, hot corners, Astra Monitor in the top bar | None. Apps: Super+Alt+Space. Activity: Super+Ctrl+T (btop) or Mission Center |
| WhiteSur theme, Sonoma wallpapers | Omarchy's themes (Solitude by default). kitty follows them, with a see-through background over Hyprland's blur |
| Docker group added directly | Omarchy's `omarchy-setup-security-sudoless-docker` explains the risk and asks first |

zsh replaces Omarchy's bash, so Omarchy's bash aliases and starship prompt aren't used. `linux/shell/zshrc`
activates mise, which Omarchy uses to install `claude` and `gh`.

## AUR packages

`packages/aur.txt` lists Chrome, pgAdmin, espanso, Citrix Workspace and Cloudflare WARP. On Ubuntu these come from signed vendor
repositories or checksum-verified downloads. On Arch they come from AUR build scripts, which individual volunteers
maintain and yay runs without showing them. Read one before the first install with `yay -Gp <name>`.

## Cloudflare WARP

On this machine's BSNL connection, downloads from Fastly (PyPI for uv and pip, GitHub, Flathub) crawled at about
2 Mbit/s per connection, with 6–7% of packets arriving out of order, while Google and Cloudflare gave 130–200 Mbit/s.
Speed tests looked fine because they open many connections at once. Through WARP, Cloudflare's free VPN, the same
PyPI download ran at 70–116 Mbit/s with no reordering, so the `tools` step turns it on at every boot.

All traffic then leaves through Cloudflare, and websites see a Cloudflare address. Local network devices stay outside
the tunnel. `warp-cli disconnect` turns it off (for example if a work VPN or Citrix misbehaves); `warp-cli connect`
turns it back on and keeps it on across reboots. On a connection without this problem, leave it off.

If Cloudflare stops passing traffic, `warp/warp-fallback` keeps the internet working. A user timer runs it every
minute:

| Situation | What it does |
|---|---|
| WARP on, pages load | Nothing |
| WARP on, nothing loads through it, but the normal connection works | Switches WARP off, notifies, and tries WARP again every 5 minutes; switches back once it works |
| Nothing loads with or without WARP | Leaves WARP on: the connection itself is down, so switching would only flap |
| On the fallback, and another VPN (from the VPN bar widget, say) now carries the traffic | Ends the fallback and leaves WARP off, so two tunnels never share the routes |
| WARP switched off by hand | Leaves it off. Only a fallback it started itself is undone |

Run `warp-fallback` in a terminal to see what it decides, or `journalctl --user -u warp-fallback` for its history.

## Shell plugins

`plugins/plugins.txt` lists the Omarchy shell plugins from [plugins.omarchy.org](https://plugins.omarchy.org), each
pinned to the commit whose full source was read before it was installed. Plugins run unsandboxed inside
`omarchy-shell` with your user's rights, and the marketplace's "Verified" label means automated checks passed, not a
security audit. When a plugin's code moves past its pinned commit, the `plugins` step says so and prints the
`git log -p` command to read the change. Update a plugin with `omarchy plugin update <id>`, which shows the diff
first, then move its commit in `plugins.txt`.

| Plugin | What it is for | Know before using |
|---|---|---|
| GitHub | PRs, reviews, issues, Actions in the bar | Notifications need `gh auth refresh -s notifications` |
| Herdr | Running herdr servers and their agents | Deleting a stopped session takes one click |
| Port Watch | Local dev servers and listening ports | Stops only your own processes, after a second click |
| Session Browser | Resume Claude Code, Codex and other agent sessions | |
| Docker | Running containers and their RAM limits | Hovering a row and pressing ←/→ changes its memory limit at once |
| X-Ray | Trace a window, port, container or file to its process | Ctrl+P pauses the selected process without asking |
| Agent Skills Manager | Every skill and MCP server the coding agents load | Read-only |
| Toolroll | Offline JSON, JWT, hash and format tools | Saves each tool's last input to `~/.local/state/omarchy/toolroll.json`; don't paste secrets |
| Clockwork | Pomodoro, stopwatch, timers | |
| Screen Time | Per-app screen time | History stays local |
| Omaplug | Browse, enable and remove plugins | Its Update buttons apply new code without showing it; update from a terminal |
| Which Key | Shortcut guide while a modifier is held | Its keyboard hook refuses the symlinked `hypr/bindings.lua`, so the guide stays off |
| VPN (fork) | Switch between Cloudflare WARP and Proton, Mullvad, Windscribe or NetworkManager VPNs | Installed from Quantum-vik/omarchy-vpn, which adds WARP; turning one VPN on turns the others off. Accept WARP's terms once (click the hint in its panel) |
| OmaStats | One CPU readout in the bar; its dropdown has CPU, memory, disks, network, sensors and battery | Looks up the public IP (ipify, icanhazip, ifconfig.me) on its Network tab; `omarchy bar set crmne.omastats publicIp false` stops it |

`plugins/bar.json` is the bar layout: the coding widgets on the left after the workspaces; Clockwork, Screen Time,
Which Key, Omaplug, a single OmaStats readout and the system icons on the right. Without it every plugin lands on the right, which pushes the system icons past the screen edge on
this laptop's 1200-point-wide bar.

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
