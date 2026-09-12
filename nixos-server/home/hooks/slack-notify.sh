#!/usr/bin/env bash
# Notification hook: send a Slack Incoming Webhook alert when Claude finishes / awaits input.
# The webhook URL (secret) is managed by agenix: /run/agenix/slack-webhook (env-file: SLACK_WEBHOOK_URL=...).
#   → encrypted as secrets/slack-webhook.age in the repo; the decryption key lives outside the repo.
#   → owner set in secrets.nix so the user (alicek106) can read it. (exit silently if the file is absent)
set -uo pipefail

SECRET="/run/agenix/slack-webhook"
[ -r "$SECRET" ] || exit 0
# Parse only the value instead of sourcing the env-file (prevents arbitrary code execution if the secret is tampered with).
url=$(grep -m1 '^SLACK_WEBHOOK_URL=' "$SECRET" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
[ -n "$url" ] || exit 0

input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // "Task done / awaiting input"')
payload=$(jq -n --arg t "Claude Code: $msg" '{text: $t}')

curl -s --max-time 5 -H 'Content-Type: application/json' -d "$payload" "$url" >/dev/null 2>&1 || true
exit 0
