-- windowrules.lua

hl.window_rule({
  name = "vesktop",
  match = { title = "Discord*" },
  fullscreen = true,
  workspace = "3"
})

hl.window_rule({
  name = "spotify",
  match = { class = "spotify" },
  workspace = "special:magic"
})
