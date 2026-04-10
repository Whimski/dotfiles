#!/bin/bash

export HYPRLAND_INSTANCE_SIGNATURE="$(ls /run/user/$UID/hypr/ | head -n 1)"

gsettings set org.gnome.desktop.interface color-scheme prefer-light
hyprctl setcursor "Catppuccin Mocha Lavender" 24
