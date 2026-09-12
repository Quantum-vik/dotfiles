# dotfiles

Personal configuration files.

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
