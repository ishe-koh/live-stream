#!/bin/bash
set -euo pipefail

PROFILE="$1"
YOUTUBE_URL="https://youtube.com/live/Q1iO0m3z5T4?feature=share"


if [[ -z "$PROFILE" ]]; then
  echo "usage: switch-profile.sh <profile>" >&2
  exit 1
fi

BASE="/opt/live-stream"

echo "PROFILE=${PROFILE}" > "${BASE}/profile.env"
systemctl restart live-stream.service

/opt/live-stream/bin/notify_slack.sh \
"🔁 プロファイル切替
🔗 ${YOUTUBE_URL}
profile=${PROFILE}
by=cron
time=$(date '+%F %T')"
