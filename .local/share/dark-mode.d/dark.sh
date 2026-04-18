#!/bin/bash

export HYPRLAND_INSTANCE_SIGNATURE="$(hyprctl instances | head -n1 | cut -d' ' -f2 | sed 's/://')"

gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-latte-green-standard+default'
hyprctl setcursor "Catppuccin Mocha Green" 24
#gsettings set org.gnome.desktop.interface icon-theme "icon-pack"
