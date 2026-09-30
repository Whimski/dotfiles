#!/usr/bin/env bash
# Toggle tuios "chrome": the dock and shared borders together.
# Compact = dock hidden + shared borders; full = dock on top + separate borders.
# Bound in kitty to ctrl+shift+b (tuios has no action that runs a command).

if [[ "$(tuios get-config dockbar_position)" == *hidden* ]]; then
    tuios set-config dockbar_position top >/dev/null
    tuios set-config shared_borders false >/dev/null
else
    tuios set-config dockbar_position hidden >/dev/null
    tuios set-config shared_borders true >/dev/null
fi
