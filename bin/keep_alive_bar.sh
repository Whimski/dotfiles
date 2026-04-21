#!/bin/bash

start_processes() {
    for name in "$@"; do
        if [[ "$name" == *"qs"* ]]; then
          process_name=$name
          name="qs"
        fi
        pids=$(pgrep "$name")

        if [ -z "$pids" ]; then
            echo "No running processes found with name: $name"
            echo "Starting now.."
            if [[ -z "$process_name" ]]; then
              setsid sh -c "$name" >/dev/null 2>&1 < /dev/null &!
            else
              setsid sh -c "$process_name" >/dev/null 2>&1 < /dev/null &!
            fi
        fi
    done
}

# Main script logic

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <process_name1> [process_name2 ...]"
    exit 1
fi

while true; do
  start_processes "$@"
  sleep 15
done
