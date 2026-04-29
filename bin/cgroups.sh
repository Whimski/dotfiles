#!/usr/bin/env bash

CGROUP_DIR="/sys/fs/cgroup"

help() {
  RED="\e[31m"
  GREEN="\e[32m"
  YELLOW="\e[33m"
  BLUE="\e[34m"
  CYAN="\e[36m"
  BOLD="\e[1m"
  RESET="\e[0m"
  
  printf "${BOLD}${CYAN}Usage:${RESET}\n"
  printf "  %s <cgroup> <action> [value]\n\n" "$0"

  printf "${BOLD}${CYAN}Actions:${RESET}\n"
  printf "  ${GREEN}%-22s${RESET} %s\n" "create" "Create a new cgroup"
  printf "  ${RED}%-22s${RESET} %s\n" "delete" "Delete cgroup and move tasks to root"
  printf "  ${YELLOW}%-22s${RESET} %s\n" "add <process-name>" "Add matching processes to cgroup"
  printf "  ${YELLOW}%-22s${RESET} %s\n" "add pid <PID>" "Add specific PID to cgroup"
  printf "  ${BLUE}%-22s${RESET} %s\n" "cat <file>" "Display cgroup control file"
  printf "  ${BLUE}%-22s${RESET} %s\n" "show | ls" "List cgroup files"
  printf "  ${CYAN}%-22s${RESET} %s\n\n" "<file> <value>" "Write value to controller file"

  printf "${BOLD}${CYAN}Examples:${RESET}\n"
  printf "  ${GREEN}%s web create${RESET}\n" "$0"
  printf "  ${YELLOW}%s web add nginx${RESET}\n" "$0"
  printf "  ${YELLOW}%s web add pid 1234${RESET}\n" "$0"
  printf "  ${CYAN}%s web memory.max 1G${RESET}\n" "$0"
  printf "  ${CYAN}%s web cpu.max \"50000 100000\"${RESET}\n" "$0"
  printf "  ${BLUE}%s web cat memory.current${RESET}\n" "$0"
  printf "  ${BLUE}%s web show${RESET}\n\n" "$0"

  printf "${BOLD}${CYAN}Notes:${RESET}\n"
  printf "  • Requires cgroup v2\n"
  printf "  • Most actions require sudo\n"
  printf "  • Cgroup path: /sys/fs/cgroup\n"
}

GROUP_NAME="${1,,}"
ACTION="${2,,}"
SUB_ACTION="${3,,}"
APP_GROUP="${CGROUP_DIR}/${GROUP_NAME}"

if [[ "$ACTION" == "create" ]]; then
  echo Creating cgroup \"$GROUP_NAME\"
  sudo mkdir -p $APP_GROUP
elif [[ "$ACTION" == "delete" ]]; then
  for pid in $(cat ${APP_GROUP}/cgroup.procs); do
    echo "$pid" | sudo tee ${CGROUP_DIR}/cgroup.procs > /dev/null
    echo "Moving PID: $pid into cgroup BASE"
  done
  sudo rmdir $APP_GROUP
elif [[ "$ACTION" == "add" ]]; then
  if [[ "$SUB_ACTION" == "pid" ]]; then
    echo $4 | sudo tee ${APP_GROUP}/cgroup.procs > /dev/null
    echo Moving $4 to cgroup: $GROUP_NAME
  else
    for pid in $(pgrep "${SUB_ACTION}"); do
      echo "$pid" | sudo tee ${APP_GROUP}/cgroup.procs > /dev/null
      echo "Moving PID: $pid into cgroup $GROUP_NAME"
    done
  fi
elif [[ "$ACTION" == "cat" ]]; then
  cat ${APP_GROUP}/${SUB_ACTION}
elif [[ "$ACTION" == "show" ]] || [[ "$ACTION" == "ls" ]]; then
  ls ${APP_GROUP}
elif [ -n "$ACTION" ] && [ -n "$SUB_ACTION" ]; then
  echo "$SUB_ACTION" | sudo tee ${APP_GROUP}/${ACTION} > /dev/null
  echo Setting ${ACTION} to "$SUB_ACTION"
elif [ "$#" -lt 3 ]; then
  help
else
  help
fi

