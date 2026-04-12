#!/bin/bash

# Function to suspend processes by name
suspend_processes() {
    for name in "$@"; do
        pids=$(pgrep "$name")

        if [ -z "$pids" ]; then
            echo "No running processes found with name: $name"
        else
            for pid in $pids; do
                kill -SIGSTOP $pid
                echo "Suspended $name (PID: $pid)"
            done
        fi
    done
}

# Function to resume processes by name
resume_processes() {
    for name in "$@"; do
        pids=$(pgrep "$name")

        if [ -z "$pids" ]; then
            echo "No running processes found with name: $name"
        else
            for pid in $pids; do
                kill -SIGCONT $pid
                echo "Resumed $name (PID: $pid)"
            done
        fi
    done
}

# Main script logic

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <suspend|resume> <process_name1> [process_name2 ...]"
    exit 1
fi

action="$1"
shift   # removes the action, leaving only process names

if [ "$action" == "suspend" ]; then
    suspend_processes "$@"
elif [ "$action" == "resume" ]; then
    resume_processes "$@"
else
    echo "Invalid action: $action. Use 'suspend' or 'resume'."
    exit 1
fi
