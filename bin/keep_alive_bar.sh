#!/usr/bin/env bash

[[ $# -eq 0 ]] && {
    echo "Usage: $0 <command> [args...]"
    exit 1
}

while true; do
    if ! pgrep -f -- "$*" >/dev/null; then
        echo "[+] Starting: $*"
        setsid "$@" >/dev/null 2>&1 </dev/null &
    fi
    sleep 5
done
