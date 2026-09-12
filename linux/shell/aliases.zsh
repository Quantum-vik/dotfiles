# Personal aliases & shell tweaks — lives in Oh My Zsh custom/ so it survives updates.

# free up Ctrl-S / Ctrl-Q (disable terminal flow control) for tmux prefix
stty -ixon 2>/dev/null

alias tm="tmux"       # launch tmux
alias cc="claude --dangerously-skip-permissions"     # Claude Code
alias lg="lazygit"    # lazygit

# make `clear` wipe the whole scrollback buffer, not just the visible screen
alias clear='command clear && printf "\033[3J"'

# tmux attach helpers
alias tma="tmux attach"      # reattach to last session
alias tml="tmux ls"          # list sessions
