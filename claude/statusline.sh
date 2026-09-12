#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Get session-wide token usage from context_window
TOKENS_IN=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOKENS_OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
TOTAL_TOKENS=$((TOKENS_IN + TOKENS_OUT))

# Format tokens with K suffix (show decimal for precision)
format_tokens() {
  local n=$1
  if [ "$n" -ge 1000 ]; then
    # Show decimal: 98.6K
    awk "BEGIN {printf \"%.1fK\", $n / 1000}"
  else
    echo "$n"
  fi
}

TOKENS_IN_FMT=$(format_tokens $TOKENS_IN)
TOKENS_OUT_FMT=$(format_tokens $TOKENS_OUT)
TOTAL_FMT=$(format_tokens $TOTAL_TOKENS)

# Session cost (resets on /clear)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
COST_FMT=""
[ -n "$COST" ] && COST_FMT=$(awk "BEGIN {printf \"\$%.2f\", $COST}")

# Cache-hit ratio: share of this turn's input served cheap from cache (⚠ if low)
CACHE_READ=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
FRESH_IN=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CACHE_FMT=""
if [ -n "$CACHE_READ" ]; then
  DENOM=$((CACHE_READ + FRESH_IN))
  if [ "$DENOM" -gt 0 ]; then
    HIT=$((CACHE_READ * 100 / DENOM))
    if [ "$HIT" -lt 70 ]; then CACHE_FMT="⚠cache ${HIT}%"; else CACHE_FMT="cache ${HIT}%"; fi
  fi
fi

# Context size tag (1M vs 200k) + warning when past 200k tokens
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
SIZE_TAG=""
if [ -n "$CTX_SIZE" ]; then
  if [ "$CTX_SIZE" -ge 1000000 ]; then SIZE_TAG="1M"; else SIZE_TAG=$(awk "BEGIN {printf \"%.0fk\", $CTX_SIZE/1000}"); fi
fi
[ "$(echo "$input" | jq -r '.exceeds_200k_tokens // false')" = "true" ] && SIZE_TAG="${SIZE_TAG}⚠"

# Reasoning effort level
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

# Context window progress bar
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

# Git branch + dirty flag (from the session's working dir)
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
GIT=""
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  DIRTY=""
  [ -n "$(git -C "$CWD" status --porcelain 2>/dev/null)" ] && DIRTY="*"
  GIT="⎇ ${BRANCH}${DIRTY}"
fi

# Format an epoch reset time as a compact countdown (e.g. 2h13m, 3d, 45m)
NOW=$(date +%s)
countdown() {
  local target=$1
  local secs=$((target - NOW))
  [ "$secs" -le 0 ] && { echo "now"; return; }
  local d=$((secs / 86400))
  local h=$(((secs % 86400) / 3600))
  local m=$(((secs % 3600) / 60))
  local s=$((secs % 60))
  if [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else echo "${m}m${s}s"; fi
}

# Plan usage limits (Pro/Max only; appear after first API response, each may be absent)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

LIMITS=""
if [ -n "$FIVE_H" ]; then
  LIMITS="Session $(printf '%.0f' "$FIVE_H")%"
  [ -n "$FIVE_H_RESET" ] && LIMITS="$LIMITS ·$(countdown "$FIVE_H_RESET")"
fi
if [ -n "$WEEK" ]; then
  LIMITS="${LIMITS:+$LIMITS · }Week $(printf '%.0f' "$WEEK")%"
  [ -n "$WEEK_RESET" ] && LIMITS="$LIMITS ·$(countdown "$WEEK_RESET")"
fi

LINE="[$MODEL] $BAR $PCT%${SIZE_TAG:+/$SIZE_TAG}"
[ -n "$EFFORT" ] && LINE="$LINE ⚡$EFFORT"
LINE="$LINE | In:$TOKENS_IN_FMT Out:$TOKENS_OUT_FMT Total:$TOTAL_FMT"
[ -n "$COST_FMT" ] && LINE="$LINE $COST_FMT"
[ -n "$CACHE_FMT" ] && LINE="$LINE $CACHE_FMT"
[ -n "$GIT" ] && LINE="$LINE | $GIT"
[ -n "$LIMITS" ] && LINE="$LINE | $LIMITS"
echo "$LINE"
