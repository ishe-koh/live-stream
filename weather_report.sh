#!/bin/bash
echo "[weather] reporter allived"
set -euo pipefail

BASE="/opt/live-stream"

source "${BASE}/profile.env"
source "${BASE}/profiles/profile_groups.conf"

LAT="35.7126"
LON="139.7036"

OFFSET=$((35 * 60))  # 35分（秒）

SUN_JSON=$(curl -s "https://api.sunrise-sunset.org/json?lat=${LAT}&lng=${LON}&formatted=0")

SUNRISE_UTC=$(echo "$SUN_JSON" | jq -r '.results.sunrise')
SUNSET_UTC=$(echo "$SUN_JSON" | jq -r '.results.sunset')

SUNRISE=$(date -d "$SUNRISE_UTC" +%s)
SUNSET=$(date -d "$SUNSET_UTC" +%s)
NOW=$(date +%s)

DAY_START=$((SUNRISE - OFFSET))   # 日の出35分前
NIGHT_START=$((SUNSET + OFFSET))  # 日の入り35分後

if (( NOW >= DAY_START && NOW < NIGHT_START )); then
  TARGET_GROUP="day"
else
  TARGET_GROUP="night"
fi

CURRENT_GROUP=$(grep "^${PROFILE}=" "${BASE}/profiles/profile_groups.conf" | cut -d= -f2)

if [[ "$CURRENT_GROUP" == "$TARGET_GROUP" ]]; then
  echo "[weather] already ${PROFILE} (${CURRENT_GROUP})"
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

echo "[weather] change profile from ${PROFILE} to ${TARGET_PROFILE} "

exec "${BASE}/switch_profile.sh" "$TARGET_PROFILE" "weather_report"
