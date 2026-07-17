#!/usr/bin/env bash

[[ $# -eq 0 ]] && {
    echo "Usage: $0 <command> [args...]"
    exit 1
}

cmd=("$@")

while true; do
    if ! pgrep "qs" >/dev/null; then
        echo "Starting: ${cmd[*]}"
        nohup "${cmd[@]}" >/dev/null 2>&1 &
    fi
    sleep 5
done
