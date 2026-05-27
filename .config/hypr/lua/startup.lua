-- startup.lua

hl.exec_once = {
    "vesktop",
    "LD_PRELOAD=/usr/lib/spotify-adblock.so spotify",
    "python ~/dotfiles/scripts/clipboard.py",
}
