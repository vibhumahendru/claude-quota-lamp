# Quota Lamp

A live readout of my Claude Code limits — the 5-hour session window and the
weekly all-models window — on a page I can open from anywhere.

## How it works

Claude Code passes `rate_limits.five_hour.used_percentage` and
`rate_limits.seven_day.used_percentage` to whatever command is configured as
the status line. There is no API for these numbers; they arrive as a side
effect of the Mac talking to Anthropic.

    Claude Code ──▶ statusline.sh ──▶ usage.json ──▶ GitHub Pages ──▶ phone
                    (prints a line)   (pushed, throttled)

- `statusline.sh` — prints the terminal status line, writes the numbers to
  `~/.claude/quota-usage.json`, and kicks off a detached push.
- `push.sh` — publishes at most once every 2 minutes, only when the numbers
  have actually changed, amending a single commit so the repo stays small.
- `index.html` — polls `usage.json` every 30s and draws two bars.
  Green under 60%, amber 60–85%, red above.

## Wiring it up

`~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/Desktop/claude-quota-lamp/statusline.sh",
  "refreshInterval": 30
}
```

## Known limits

- Numbers only move while Claude Code is running on the Mac. Usage from the
  claude.ai web app or phone counts against the same pot but is not seen here
  until the next local session. The page dims and says so after 30 minutes.
- Only two windows are exposed: 5-hour and weekly-all-models. The Max
  Opus-only weekly cap is visible in claude.ai → Settings → Usage, but is not
  in the status line feed.
- `rate_limits` is absent for free accounts, and for the first message of any
  session before the first API response.
