#!/bin/bash
# Publishes ~/.claude/quota-usage.json to GitHub Pages.
# Throttled and locked, because the status line calls this constantly.

set -u
repo="$HOME/Desktop/claude-quota-lamp"
state="$HOME/.claude/quota-usage.json"
stamp="$repo/.last-push"
lock="$repo/.push.lock"
MIN_GAP=120   # seconds between pushes, no matter how busy the session is

[ -f "$state" ] || exit 0

# throttle
if [ -f "$stamp" ]; then
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  [ $(( $(date +%s) - last )) -lt "$MIN_GAP" ] && exit 0
fi

# lock (mkdir is atomic); clear a stale lock left by a killed run
if ! mkdir "$lock" 2>/dev/null; then
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then rmdir "$lock" 2>/dev/null; fi
  exit 0
fi
trap 'rmdir "$lock" 2>/dev/null' EXIT

cd "$repo" || exit 0

# nothing new to say?
if cmp -s "$state" "$repo/usage.json"; then
  date +%s > "$stamp"
  exit 0
fi

cp "$state" "$repo/usage.json"
git add -A >/dev/null 2>&1

# keep history at a single commit so the repo never grows
if git rev-parse HEAD >/dev/null 2>&1; then
  git commit -q --amend -m "quota lamp" --date=now >/dev/null 2>&1
  git push -q --force origin HEAD:main >/dev/null 2>&1
else
  git commit -q -m "quota lamp" >/dev/null 2>&1
  git push -q origin HEAD:main >/dev/null 2>&1
fi

date +%s > "$stamp"
