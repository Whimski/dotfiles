#!/bin/bash

TARGET_DIR="/home/tobi/dotfiles"

find "$TARGET_DIR" -type d -exec chmod 755 {} \;
find "$TARGET_DIR" -type f -exec chmod 644 {} \;
find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" -o -name "*.cgi" -o -name "dotfiles*" \) -exec chmod 755 {} \;

chmod 600 .ssh/*
chmod 644 .ssh/*.pub
