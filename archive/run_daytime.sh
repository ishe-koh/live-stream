#!/bin/bash
set -euo pipefail

STREAM_KEY_FILE="/etc/streamer/stream_key"
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"

STREAM_KEY="$(cat "$STREAM_KEY_FILE")"

exec rpicam-vid \
  --width 2304 --height 1296 --framerate 30 \
  --rotation 180 \
  --codec yuv420 \
  --sharpness 0.4 --contrast 0.85 \
  --nopreview \
  -t 0 \
  -o - | \
ffmpeg \
  -f rawvideo -pix_fmt yuv420p -s 2304x1296 -r 30 -i - \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
  -map 0:v -map 1:a \
  -c:v libx264 \
  -preset veryfast -tune zerolatency \
  -b:v 14000k -maxrate 14000k -bufsize 28000k \
  -x264-params "scenecut=0:keyint=120:min-keyint=120" \
  -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv \
  "${RTMP_URL}/${STREAM_KEY}"
