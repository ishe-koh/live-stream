#!/bin/bash
set -euo pipefail

DEBUG="${DEBUG:-true}"

log_debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo "[$(date '+%F %T')] [DEBUG] $1"
  fi
}

BASE="/opt/live-stream"

source "${BASE}/profile.env"
source "${BASE}/profiles/profile_groups.conf"

LAT="35.7126"
LON="139.7036"

OFFSET=$((35 * 60))  # 35分（秒）

TODAY_JST=$(date +%F)
SUN_JSON=$(curl --fail --silent --show-error --max-time 20 \
  "https://api.sunrise-sunset.org/json?lat=${LAT}&lng=${LON}&formatted=0&date=${TODAY_JST}")

if [[ $(jq -r '.status // empty' <<<"$SUN_JSON") != "OK" ]]; then
  echo "${TODAY_JST} [weather] sunrise-sunset API returned an error" >&2
  exit 1
fi

SUNRISE_UTC=$(echo "$SUN_JSON" | jq -r '.results.sunrise')
SUNSET_UTC=$(echo "$SUN_JSON" | jq -r '.results.sunset')

SUNRISE=$(date -d "$SUNRISE_UTC" +%s)
SUNSET=$(date -d "$SUNSET_UTC" +%s)
NOW=$(date +%s)

DAY_START=$((SUNRISE - OFFSET))   # 日の出35分前
NIGHT_START=$((SUNSET + OFFSET))  # 日の入り35分後

TS=$(date '+%Y-%m-%d %H:%M:%S')


log_debug "SUNRISE(local)=$(date -d "@$SUNRISE")"
log_debug "SUNSET(local)=$(date -d "@$SUNSET")"
log_debug "DAY_START(local)=$(date -d "@$DAY_START")"
log_debug "NIGHT_START(local)=$(date -d "@$NIGHT_START")"
log_debug "NOW(local)=$(date -d "@$NOW")"


if (( NOW >= DAY_START && NOW < NIGHT_START )); then
  TARGET_GROUP="day"
else
  TARGET_GROUP="night"
fi

CURRENT_GROUP=$(awk -F= -v profile="$PROFILE" '$1 == profile { print $2 }' \
  "${BASE}/profiles/profile_groups.conf")

if [[ -z "$CURRENT_GROUP" ]]; then
  echo "${TS} [weather] profile group is undefined: ${PROFILE}" >&2
  exit 1
fi

if [[ "$CURRENT_GROUP" == "$TARGET_GROUP" ]]; then
  echo "${TS} [weather] already ${PROFILE} (${CURRENT_GROUP})"
  exit 0
fi

case "$TARGET_GROUP" in
  day)
    TARGET_PROFILE="day"
    ;;
  night)
    TARGET_PROFILE="night"
    ;;
esac

echo "${TS} [weather] change profile from ${PROFILE} to ${TARGET_PROFILE} "

exec "${BASE}/switch_profile.sh" "$TARGET_PROFILE" "weather_report"
