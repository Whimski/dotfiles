#!/bin/bash

# Function to suspend processes by name
suspend_processes() {
    # Get the list of PIDs for the given process name
    pids=$(pgrep "$1")

    if [ -z "$pids" ]; then
        echo "No running processes found with name: $1"
    else
        # Suspend each process
        for pid in $pids; do
            kill -SIGSTOP $pid
            echo "Suspended process with PID: $pid"
        done
    fi
}

# Function to resume processes by name
resume_processes() {
    # Get the list of PIDs for the given process name
    pids=$(pgrep "$1")

    if [ -z "$pids" ]; then
        echo "No running processes found with name: $1"
    else
        # Resume each process
        for pid in $pids; do
            kill -SIGCONT $pid
            echo "Resumed process with PID: $pid"
        done
    fi
}

# Main script logic

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <suspend|resume> <process_name>"
    exit 1
fi

action="$1"
process_name="$2"

if [ "$action" == "suspend" ]; then
    suspend_processes "$process_name"
elif [ "$action" == "resume" ]; then
    resume_processes "$process_name"
else
    echo "Invalid action: $action. Use 'suspend' or 'resume'."
    exit 1
fi
