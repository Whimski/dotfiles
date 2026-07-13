#!/usr/bin/env bash

APP="$1"

"$APP" >/dev/null 2>&1 &
sleep 5

PROCESS=$(pgrep -af "/tmp/.mount_" | awk '{print $2}' | head -1)

echo "Detected process: $PROCESS"

while true; do
    if ! pgrep -f "$PROCESS" >/dev/null; then
        echo "[+] Restarting"
        "$APP" >/dev/null 2>&1 &
        sleep 5
    fi
    sleep 5
done
