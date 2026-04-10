#!/bin/bash

export HYPRLAND_INSTANCE_SIGNATURE="$(ls /run/user/$UID/hypr/ | head -n 1)"

gsettings set org.gnome.desktop.interface color-scheme prefer-dark
hyprctl setcursor "Catppuccin Mocha Green" 24
#gsettings set org.gnome.desktop.interface icon-theme "icon-pack"
