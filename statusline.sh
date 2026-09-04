#!/bin/bash
# Claude Code status line -> prints a line for the terminal, and records the
# quota numbers for the Quota Lamp page.  Must be fast and must never block.

input=$(cat)
state="$HOME/.claude/quota-usage.json"
repo="$HOME/Desktop/claude-quota-lamp"

get() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

five=$(get  '.rate_limits.five_hour.used_percentage')
week=$(get  '.rate_limits.seven_day.used_percentage')
fr=$(get    '.rate_limits.five_hour.resets_at')
wr=$(get    '.rate_limits.seven_day.resets_at')
ctx=$(get   '.context_window.used_percentage')
model=$(get '.model.display_name')
dir=$(get   '.workspace.current_dir')

# ---------- record for the lamp ----------
if [ -n "$five" ] || [ -n "$week" ]; then
  jq -n --argjson five "${five:-null}" --argjson week "${week:-null}" \
        --argjson fr "${fr:-null}"     --argjson wr "${wr:-null}"     \
        --argjson now "$(date +%s)"                                    \
        '{five:$five, week:$week, five_resets:$fr, week_resets:$wr, updated:$now}' \
        > "$state.tmp" 2>/dev/null && mv "$state.tmp" "$state"
  # publish, throttled, fully detached so the terminal never waits on the network
  ( "$repo/push.sh" >/dev/null 2>&1 & ) &
fi

# ---------- draw the terminal line ----------
bar() {
  local p=${1%%.*}
  if [ -z "$p" ]; then printf '\033[2m░░░░░\033[0m'; return; fi
  local n=$(( (p + 19) / 20 )); [ "$n" -gt 5 ] && n=5
  local c=32; [ "$p" -ge 60 ] && c=33; [ "$p" -ge 85 ] && c=31
  local i s=''
  for ((i = 0; i < 5; i++)); do
    if [ "$i" -lt "$n" ]; then s="$s▓"; else s="$s░"; fi
  done
  printf '\033[%sm%s\033[0m' "$c" "$s"
}

pct() { [ -n "$1" ] && printf '\033[2m%3s%%\033[0m' "${1%%.*}" || printf '\033[2m   -\033[0m'; }

printf '\033[2m%s · %s\033[0m   ' "${model:-Claude}" "$(basename "${dir:-$PWD}")"
printf 'ctx '; bar "$ctx";  pct "$ctx";  printf '   '
printf '5h ';  bar "$five"; pct "$five"; printf '   '
printf '7d ';  bar "$week"; pct "$week"; printf '\n'
