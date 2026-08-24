#!/bin/bash

set -euo pipefail

BASE_DIR="/opt/live-stream"
PROFILE_FILE="${BASE_DIR}/profile.env"

source "$PROFILE_FILE"
source "${BASE_DIR}/profiles/${PROFILE}.conf"
echo "[profile] PROFILE=${PROFILE}" >&2
echo "[profile] using profiles/${PROFILE}.conf" >&2

STREAM_KEY="$(cat /etc/streamer/stream_key)"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"

CAM_OPTS=(
  --width "$WIDTH"
  --height "$HEIGHT"
  --framerate "$FPS"
  --rotation 180
  --codec yuv420
  --nopreview
  -t 0
  -o -
)
[[ -n "${SHUTTER:-}"   ]] && CAM_OPTS+=(--shutter "$SHUTTER")
[[ -n "${GAIN:-}"      ]] && CAM_OPTS+=(--gain "$GAIN")
[[ -n "${AWB:-}"       ]] && CAM_OPTS+=(--awb "$AWB")
[[ -n "${METERING:-}"  ]] && CAM_OPTS+=(--metering "$METERING")
[[ -n "${DENOISE:-}"   ]] && CAM_OPTS+=(--denoise "$DENOISE")

echo "[profile] ${PROFILE}" >&2
echo "[profile] cam opts: ${CAM_OPTS[*]}" >&2

exec rpicam-vid "${CAM_OPTS[@]}" | \
ffmpeg \
  -f rawvideo -pix_fmt yuv420p -s ${WIDTH}x${HEIGHT} -r "$FPS" -i - \
  -stream_loop -1 -i /opt/live-stream/media/banner/entas_banner_fixed.mp4 \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -filter_complex "
    [0:v]setpts=PTS-STARTPTS[cam];
    [1:v]fps=10,format=yuv420p,setpts=PTS-STARTPTS[banner];
    [cam][banner]overlay=0:${HEIGHT}-144[outv]
  " \
  -map "[outv]" \
  -map 2:a \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -b:v 9000k -maxrate 9000k -bufsize 18000k \
  -g 60 -keyint_min 60 \
  -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv \
  "${RTMP_URL}/${STREAM_KEY}"
