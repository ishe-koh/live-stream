#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <profile> [source]" >&2
  exit 2
fi

REQUESTED_PROFILE="$1"
SOURCE="${2:-manual}"
YOUTUBE_URL="https://youtube.com/live/Q1iO0m3z5T4?feature=share"
BASE="/opt/live-stream"
PROFILE_FILE="${BASE}/profile.env"
PROFILE_CONFIG="${BASE}/profiles/${REQUESTED_PROFILE}.conf"

if [[ ! "$REQUESTED_PROFILE" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ ! -f "$PROFILE_CONFIG" ]]; then
  echo "unknown profile: ${REQUESTED_PROFILE}" >&2
  exit 2
fi

# Daily reset and profile changes must not control the service concurrently.
exec 9>/run/lock/live-stream-control.lock
flock 9

CURRENT_PROFILE=""
if [[ -r "$PROFILE_FILE" ]]; then
  source "$PROFILE_FILE"
  CURRENT_PROFILE="${PROFILE:-}"
fi

if [[ "$CURRENT_PROFILE" == "$REQUESTED_PROFILE" ]]; then
  echo "profile already active: $REQUESTED_PROFILE"
  exit 0
fi

TEMP_FILE=$(mktemp "${BASE}/.profile.env.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT
printf 'PROFILE=%s\n' "$REQUESTED_PROFILE" > "$TEMP_FILE"
if [[ -e "$PROFILE_FILE" ]]; then
  chmod --reference="$PROFILE_FILE" "$TEMP_FILE"
  chown --reference="$PROFILE_FILE" "$TEMP_FILE"
fi
mv "$TEMP_FILE" "$PROFILE_FILE"
trap - EXIT

systemctl restart live-stream.service

if ! /opt/live-stream/bin/notify_slack.sh \
"🔁 プロファイル切替
🔗 ${YOUTUBE_URL}
profile=${REQUESTED_PROFILE}
by=${SOURCE}
time=$(date '+%F %T')"; then
  echo "warning: profile switched, but Slack notification failed" >&2
fi
