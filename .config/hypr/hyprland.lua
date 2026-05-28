-- hyprland.lua



-- ─────────────────────────────────────────────
-- Sources
-- ─────────────────────────────────────────────

require("mocha")
require("monitors")
require("startup")
require("windowrules")

-- ─────────────────────────────────────────────
-- Variables
-- ─────────────────────────────────────────────

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"
local ipc         = "qs -c noctalia-shell ipc call"

-- require("startup")
-- require("windowrules")

-- ─────────────────────────────────────────────
-- Environment variables
-- ─────────────────────────────────────────────

 hl.env("LIBVA_DRIVER_NAME",        "nvidia"                   )
 hl.env("XDG_SESSION_TYPE",         "wayland"                  )
 hl.env("GBM_BACKEND",              "nvidia-drm"               )
 hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia"                   )
 hl.env("WLR_NO_HARDWARE_CURSORS",  "1"                        )
 hl.env("HYPRLAND_LOG_WLR",         "1"                        )
 hl.env("QT_QPA_PLATFORMTHEME",     "qt6ct"                    )
 hl.env("QT_STYLE_OVERRIDE",        "kvantum"                  )
 hl.env("XCURSOR_SIZE",             "24"                       )
 hl.env("XCURSOR_THEME",            "Catppuccin Mocha Lavender")

-- ─────────────────────────────────────────────
-- Autostart
-- ─────────────────────────────────────────────

hl.on("hyprland.start", function () 
  hl.exec_cmd('sleep 1 && hyprctl setcursor "Catppuccin Mocha Lavender" 24')
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("easyeffects --gapplication-service")
  hl.exec_cmd("qs -c noctalia-shell")
  hl.exec_cmd('~/dotfiles/bin/keep_alive_bar.sh "qs -c noctalia-shell"')
  hl.exec_cmd("ie-r")
  hl.exec_cmd("xdg-desktkop-portal")
  hl.exec_cmd("xdg-desktkop-portal-hyprland")
end)

-- hl.monitor({ output = "DP-1",     mode = "1680x1050",  refresh = 60,  position = "0x0",    scale = 1 })
-- hl.monitor({ output = "HDMI-A-2", mode = "1920x1080",  refresh = 100, position = "1680x0", scale = 1 })
-- hl.monitor({ output = "DP-2",     mode = "1920x1080",  refresh = 60,  position = "3600x0", scale = 1, transform = 1 })
    -- { name = "DP-2",  resolution = "1080x1920",  refresh = 60,  position = "3600x0", scale = 1, transform = 1 },

-- ─────────────────────────────────────────────
-- Ecosystem
-- ─────────────────────────────────────────────

hl.config({
    ecosystem = {
        no_update_news = true,
    },
})

-- ─────────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────────

hl.config({
    input = {
        kb_layout    = "us",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",
        touchpad = {
            natural_scroll = false,
        },
    },
    cursor = {
        no_hardware_cursors = true,
    },
})

-- ─────────────────────────────────────────────
-- General
-- ─────────────────────────────────────────────

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 5,
        border_size = 1,
        col = {
            active_border   = green,
            inactive_border = sapphire,
        },
        layout = "dwindle",
        allow_tearing = false,
    },
})

-- ─────────────────────────────────────────────
-- Decoration
-- ─────────────────────────────────────────────

hl.config({
    decoration = {
        rounding = 0,
        blur = {
            enabled  = true,
            size     = 10,
            passes   = 3,
            vibrancy = 0.2,
        },
    },
})


-- ─────────────────────────────────────────────
-- Animations
-- ─────────────────────────────────────────────

hl.curve("bounce",    { type = "bezier", points = { {0.34, 1.56}, {0.64, 1  } } })
hl.curve("rubber",    { type = "bezier", points = { {0.22, 1.2 }, {0.36, 1  } } })
hl.curve("overshoot", { type = "bezier", points = { {0.05, 0.9 }, {0.1,  1.1} } })

hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6, bezier = "bounce",    style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, bezier = "rubber",    style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "bounce"                         })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6, bezier = "overshoot", style = "slide"     })
hl.animation({ leaf = "fade",        enabled = true, speed = 5, bezier = "overshoot"                      })
hl.animation({ leaf = "border",      enabled = true, speed = 8, bezier = "rubber"                         })

-- ─────────────────────────────────────────────
-- Layouts
-- ─────────────────────────────────────────────

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

-- ─────────────────────────────────────────────
-- Misc
-- ─────────────────────────────────────────────

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

-- ─────────────────────────────────────────────
-- Per-device input
-- ─────────────────────────────────────────────

hl.device = {
    {
        name        = "epic-mouse-v1",
        sensitivity = -0.5,
    },
}

-- ─────────────────────────────────────────────
-- Layer rules
-- ─────────────────────────────────────────────

hl.layer_rule({ name = "no-blur-bg",            match = { namespace = "^noctalia-background.*"   }, blur = false })
hl.layer_rule({ name = "no-blur-bar-content",   match = { namespace = "^noctalia-bar-content.*"  }, blur = false })
hl.layer_rule({ name = "no-blur-bar-exclusion", match = { namespace = "^noctalia-bar-exclusion.*"}, blur = false })
hl.layer_rule({ name = "no-blur-slurp",         match = { title = "slurp"                        }, blur = false })

-- ─────────────────────────────────────────────
-- Window rules
-- ─────────────────────────────────────────────

hl.window_rule({
    name  = "microsoft-float",
    match = { class = "^(.*Microsoft.*)$" },
    float            = true,
    fullscreen_state = "0 0",
    persistent_size  = true,
})

hl.window_rule({
    name    = "global-opacity",
    match   = { class = ".*" },
    opacity = "1.0 1.0",
})

-- ─────────────────────────────────────────────
-- Keybindings
-- ─────────────────────────────────────────────

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("grimblast copy area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copy active"))

-- Resize submap
-- hl.bind(mainMod.. "+ SHIFT + R", "submap", "resize")
-- hyprland.submap("resize", function()
--     hl.binde("",      "right", "resizeactive",  "10 0")
--     hl.binde("",      "left",  "resizeactive", "-10 0")
--     hl.binde("",      "up",    "resizeactive",  "0 -10")
--     hl.binde("",      "down",  "resizeactive",  "0 10")
--     hl.binde("SHIFT", "right", "resizeactive",  "50 0")
--     hl.binde("SHIFT", "left",  "resizeactive", "-50 0")
--     hl.binde("SHIFT", "up",    "resizeactive",  "0 -50")
--     hl.binde("SHIFT", "down",  "resizeactive",  "0 50")
--     hl.bind("",       "escape", "submap", "reset")
-- end)

-- Media / volume / brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. " volume increase"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. " volume decrease"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. " volume muteOutput"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. " brightness increase"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"))
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(ipc .. " media playPause"))
-- hl.bind("XF86AudioPlayPause",    hl.dsp.exec_cmd(ipc .. " media playPause"))
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(ipc .. " media next"))

-- Window management
hl.bind(mainMod .. "+ RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. "+ SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. "+ M",      hl.dsp.exec_cmd("pkill Hyprland"))
hl.bind(mainMod .. "+ D",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. "+ SPACE",  hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. "+ P",      hl.dsp.window.pseudo())
hl.bind(mainMod .. "+ W",      hl.dsp.exec_cmd('hyprctl keyword general:layout "$(hyprctl getoption general:layout | grep -q \'dwindle\' && echo \'master\' || echo \'dwindle\')"'))
hl.bind(mainMod .. "+ F",      hl.dsp.window.fullscreen())
hl.bind(mainMod .. "+ SHIFT + I",      hl.dsp.exec_cmd("pkill -SIGUSR1 ie-r"))

-- Focus (arrows + hjkl)
hl.bind(mainMod .. "+ left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. "+ right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. "+ up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. "+ down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. "+ h",     hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. "+ l",     hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. "+ k",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. "+ j",     hl.dsp.focus({ direction = "down" }))

-- Move windows (arrows + hjkl)
hl.bind(mainMod .. "+ SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. "+ SHIFT + right", hl.dsp.window.move({ direction = "right"}))
hl.bind(mainMod .. "+ SHIFT + up",    hl.dsp.window.move({ direction = "up"}))
hl.bind(mainMod .. "+ SHIFT + down",  hl.dsp.window.move({ direction = "down"}))
hl.bind(mainMod .. "+ SHIFT + h",     hl.dsp.window.move({ direction = "left"}))
hl.bind(mainMod .. "+ SHIFT + l",     hl.dsp.window.move({ direction = "right"}))
hl.bind(mainMod .. "+ SHIFT + k",     hl.dsp.window.move({ direction = "up"}))
hl.bind(mainMod .. "+ SHIFT + j",     hl.dsp.window.move({ direction = "down"}))

-- Switch workspaces
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end
-- work on this later
-- bind(mainMod, "Tab", "workspace", "previous")

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move / resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

