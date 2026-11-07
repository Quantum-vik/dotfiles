#!/bin/bash
# SessionStart hook: if this session has no name yet, tell Claude to ask for one (see CLAUDE.md).
# Catches sessions that predate the naming rule, plus /clear and forks, which start a new session ID,
# and names that claude-session-name pruned after 30 days. Stdout from a SessionStart hook becomes context.
id=$(jq -r '.session_id // empty')
[ -n "$id" ] || exit 0
[ -s "${XDG_STATE_HOME:-$HOME/.local/state}/claude/session-names/$id" ] && exit 0
echo "This session has no name yet. Before any other work, ask the user what to call it and record it with \`claude-session-name <name>\` (the statusline shows it)."
