#!/bin/bash
# One tick of the Quota Lamp feeder.
#
# Keeps a real interactive Claude Code session alive inside a detached tmux
# session, and pokes it with a one-word message.  The reply is a genuine API
# response, so Claude Code's status line fires with fresh account-wide limit
# numbers -> statusline.sh -> usage.json -> the page.
#
# Print mode (claude -p) does NOT run the status line; only a TUI session does.
# That is the whole reason tmux is here.

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin"
SESSION="quota-lamp"
DIR="$HOME/Desktop/claude-quota-lamp"
LOG="$DIR/.tick.log"
STATE="$HOME/.claude/quota-usage.json"

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

# -------- make sure the session exists --------
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  log "starting session"
  # Start a plain shell first so the pane SURVIVES claude exiting; that way any
  # startup error stays visible instead of tearing the session down with it.
  tmux new-session -d -s "$SESSION" -x 120 -y 40 -c "$DIR"
  tmux set-option -t "$SESSION" remain-on-exit on 2>/dev/null

  # wait for the shell itself to be ready before typing into it
  for _ in $(seq 1 10); do
    sleep 1
    tmux capture-pane -pt "$SESSION" 2>/dev/null | grep -q '%' && break
  done

  # Launch claude by typing it into the shell.
  # ANTHROPIC_API_KEY unset or Claude Code bills the API key and reports no
  # subscription limits.  CLAUDECODE unset so it never thinks it is nested.
  tmux send-keys -t "$SESSION" \
    "env -u ANTHROPIC_API_KEY -u CLAUDECODE claude --model haiku --append-system-prompt 'Reply with exactly: ok'" Enter

  # Wait for claude to be the foreground process and show its input box.
  # The first-run trust dialog DEFAULTS TO "No, exit" -- so it needs Down+Enter.
  trusted=0
  for _ in $(seq 1 40); do
    sleep 1
    pane=$(tmux capture-pane -pt "$SESSION" 2>/dev/null)
    if [ "$trusted" = 0 ] && grep -q "trust this folder" <<<"$pane"; then
      tmux send-keys -t "$SESSION" Down; sleep 0.5; tmux send-keys -t "$SESSION" Enter
      trusted=1; log "accepted trust prompt (Down+Enter)"; sleep 3; continue
    fi
    fg=$(tmux display -pt "$SESSION" '#{pane_current_command}' 2>/dev/null)
    if [ "$fg" != "zsh" ] && [ "$fg" != "bash" ] && grep -q "shortcuts\|─╯\|>" <<<"$pane"; then
      log "claude ready (fg=$fg)"; break
    fi
  done
  sleep 2
fi

# never type into a bare shell -- that is how "ok" ended up as a zsh error
fg=$(tmux display -pt "$SESSION" '#{pane_current_command}' 2>/dev/null)
if [ "$fg" = "zsh" ] || [ "$fg" = "bash" ]; then
  log "claude is not running in the session (fg=$fg); killing it for a clean restart next tick"
  tmux capture-pane -pt "$SESSION" -S -60 2>/dev/null | grep -v '^[[:space:]]*$' | tail -15 >> "$LOG"
  tmux kill-session -t "$SESSION" 2>/dev/null
  exit 1
fi

# -------- poke it --------
before=$(jq -r '.updated // 0' "$STATE" 2>/dev/null || echo 0)

# /clear keeps the conversation at zero context so every poke costs the same
# tiny amount instead of growing forever.
tmux send-keys -t "$SESSION" "/clear" Enter
sleep 1.5
tmux send-keys -t "$SESSION" "ok" Enter

# wait up to 60s for the status line to write a fresh reading
for _ in $(seq 1 30); do
  sleep 2
  after=$(jq -r '.updated // 0' "$STATE" 2>/dev/null || echo 0)
  if [ "$after" != "$before" ] && [ "$after" != "0" ]; then
    log "reading: $(jq -c '{five,week}' "$STATE")"
    exit 0
  fi
done
log "no fresh reading after 60s"
exit 1
