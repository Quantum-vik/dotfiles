# dotfiles

Personal configuration files.

- [`linux/`](linux/) — full Ubuntu 24.04 GNOME desktop setup with an installer. Start there on a new Linux machine.
- [`omarchy/`](omarchy/) — the same setup on Omarchy 4 (Arch + Hyprland), reusing the configs in `linux/`.
- [`tmux/`](tmux/) — tmux config (also linked by `linux/install.sh`).
- [`claude/`](claude/) — Claude Code settings, keybindings, statusline, CLAUDE.md.

## tmux

`tmux/tmux.conf` — symlink it into place:

```bash
ln -sf ~/dotfiles/tmux/tmux.conf ~/.tmux.conf
```

Requires [TPM](https://github.com/tmux-plugins/tpm) before first launch, or the
final `run` line errors:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins
```

Notes:

- **Prefix is `Ctrl-S`**, not `Ctrl-B`. `Ctrl-S` is also XON/XOFF flow control, so add
  `stty -ixon` to your shell rc or terminal output can freeze.
- Splits are `'` (side by side) and `"` (top/bottom); the defaults `%` and `"` are unbound.
- `prefix` + arrow enters a sticky `panemove` key table — arrows keep moving panes without
  the prefix until any other key is pressed.
- Theme uses `bg=default` throughout so the terminal background shows through. Replacing
  those with a solid colour breaks the transparency.
- Needs `tmux-256color` terminfo (`ncurses-term` on Debian/Ubuntu if missing).

Plugins: tmux-resurrect + tmux-continuum, with auto-restore on and 15-minute saves.

## Claude Code

`claude/` — settings, keybindings, the custom statusline, and `CLAUDE.md`, the instructions Claude Code
reads at the start of every session on this machine.

`CLAUDE.md` has every session open by asking what to call it. Claude records the answer with
`claude-session-name`, which writes it under `~/.local/state/claude/session-names` keyed by the session id
Claude Code exports as `CLAUDE_CODE_SESSION_ID`; `statusline.sh` reads the same id back out of its own JSON
and shows the name at the front of the line. Names outlive a reboot, so a resumed session keeps its own, and
any untouched for a month are swept up.

```bash
for f in settings.json keybindings.json statusline.sh CLAUDE.md; do
  ln -sf ~/dotfiles/claude/$f ~/.claude/$f
done
chmod +x ~/.claude/statusline.sh
ln -sf ~/dotfiles/claude/claude-session-name ~/.local/bin/claude-session-name
```

`settings.json` sets `attribution` to empty with `sessionUrl: false`, so commits and pull requests made through
Claude Code carry no Co-Authored-By trailer, Claude-Session link or "Generated with Claude Code" footer.

`statusline.sh` needs `jq`, `git` and `awk`. It renders model, a context-window
progress bar, effort level, token in/out/total, session cost, cache-hit ratio
(warns below 70%), git branch with a dirty flag, and plan rate-limit countdowns.

Not tracked here, deliberately: `~/.claude.json` (contains oauthAccount, userID,
machineID), `projects/`, `history.jsonl`, `shell-snapshots/`, `cache/`.

Plugins and marketplaces are not files — reinstall them with `/plugin` inside
Claude Code rather than copying.
