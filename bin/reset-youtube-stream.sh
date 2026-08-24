#!/bin/bash
set -euo pipefail

# Serialize service control with switch_profile.sh.
exec 9>/run/lock/live-stream-control.lock
flock 9

systemctl stop live-stream.service
sleep 15
systemctl start live-stream.service
