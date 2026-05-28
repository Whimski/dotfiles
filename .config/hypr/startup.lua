-- startup.lua

hl.on("hyprland.start", function () 
  hl.exec_cmd("vesktop")
  hl.exec_cmd("LD_PRELOAD=/usr/lib/spotify-adblock.so spotify")
  hl.exec_cmd("python ~/dotfiles/scripts/clipboard.py")
end)


