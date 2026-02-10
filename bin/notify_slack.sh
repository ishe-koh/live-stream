#!/bin/bash
set -euo pipefail

WEBHOOK_FILE="/etc/streamer/slack_webhook"

if [[ ! -f "$WEBHOOK_FILE" ]]; then
  echo "Slack webhook not found" >&2
  exit 1
fi

WEBHOOK_URL="$(cat "$WEBHOOK_FILE")"

MESSAGE="$1"

payload=$(cat <<EOF
{
  "text": "$MESSAGE"
}
EOF
)

curl -s -X POST \
  -H 'Content-Type: application/json' \
  --data "$payload" \
  "$WEBHOOK_URL" >/dev/null
