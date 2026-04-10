#!/bin/bash


export HYPRLAND_INSTANCE_SIGNATURE="$(hyprctl instances | head -n1 | cut -d' ' -f2 | sed 's/://')"

gsettings set org.gnome.desktop.interface color-scheme prefer-light
hyprctl setcursor "Catppuccin Mocha Lavender" 24
