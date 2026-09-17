# Personal aliases & shell tweaks — lives in Oh My Zsh custom/ so it survives updates.

# free up Ctrl-S / Ctrl-Q (disable terminal flow control) for tmux prefix
stty -ixon 2>/dev/null

# `tmux` / `tm` with no arguments reattaches to the most recent session. The tmux server outlives a GNOME
# logout, so a bare `tmux new-session` would leave the old sessions detached and open an empty one. With no
# server (after a reboot) it starts one, and tmux-continuum restores the last tmux-resurrect save.
tmux() {
  if [[ $# -eq 0 && -z $TMUX ]]; then
    command tmux attach-session 2>/dev/null || command tmux new-session
  else
    command tmux "$@"
  fi
}
alias tm="tmux"       # launch tmux (reattaches if sessions exist)
alias cc="claude --dangerously-skip-permissions"     # Claude Code
alias lg="lazygit"    # lazygit

# make `clear` wipe the whole scrollback buffer, not just the visible screen
alias clear='command clear && printf "\033[3J"'

# tmux attach helpers
alias tma="tmux attach"      # reattach to last session
alias tml="tmux ls"          # list sessions

# Clickable file paths. A terminal can only open text a program marked as a link (OSC 8), so ask the tools that
# can. In kitty, Ctrl+click then opens the file in VS Code, at the line for ripgrep's hits: kitty/open-actions.conf
# routes it. Both flags only take effect when writing to a terminal, so piped and redirected output stays plain.
alias ls='ls --color=auto --hyperlink=auto'
if [[ -n $KITTY_WINDOW_ID || $TERM == xterm-kitty || $TERM_PROGRAM == kitty ]]; then
  alias rg='rg --hyperlink-format=kitty'     # file://host/path#line, the line kitty passes to `code --goto`
else
  alias rg='rg --hyperlink-format=default'   # plain file://host/path elsewhere (GNOME Terminal, VS Code)
fi
