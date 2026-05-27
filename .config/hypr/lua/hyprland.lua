-- hyprland.lua

local config   = hl.config
local bind     = hl.bind
local bindel   = hl.bindel
local bindl    = hl.bindl
local binde    = hl.binde
local bindm    = hl.bindm

-- ─────────────────────────────────────────────
-- Sources
-- ─────────────────────────────────────────────

hl.source = {
    "~/.config/hypr/mocha.conf",
    "~/.config/hypr/monitors.lua",
    "~/.config/hypr/startup.lua",
    "~/.config/hypr/windowrules.lua",
}

-- ─────────────────────────────────────────────
-- Variables
-- ─────────────────────────────────────────────

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun"
local ipc         = "qs -c noctalia-shell ipc call"

-- ─────────────────────────────────────────────
-- Environment variables
-- ─────────────────────────────────────────────

hl.env = {
    { "LIBVA_DRIVER_NAME",        "nvidia"                    },
    { "XDG_SESSION_TYPE",         "wayland"                   },
    { "GBM_BACKEND",              "nvidia-drm"                },
    { "__GLX_VENDOR_LIBRARY_NAME","nvidia"                    },
    { "WLR_NO_HARDWARE_CURSORS",  "1"                         },
    { "HYPRLAND_LOG_WLR",         "1"                         },
    { "QT_QPA_PLATFORMTHEME",     "qt6ct"                     },
    { "QT_STYLE_OVERRIDE",        "kvantum"                   },
    { "XCURSOR_SIZE",             "24"                        },
    { "XCURSOR_THEME",            "Catppuccin Mocha Lavender" },
}

-- ─────────────────────────────────────────────
-- Autostart
-- ─────────────────────────────────────────────

hl.exec_once = {
    'sleep 1 && hyprctl setcursor "Catppuccin Mocha Lavender" 24',
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "easyeffects --gapplication-service",
    "qs -c noctalia-shell",
    '~/dotfiles/bin/keep_alive_bar.sh "qs -c noctalia-shell"',
    "ie-r",
    "xdg-desktkop-portal",
    "xdg-desktkop-portal-hyprland",
}

-- ─────────────────────────────────────────────
-- Ecosystem
-- ─────────────────────────────────────────────

hl.ecosystem = {
    no_update_news = true,
}

-- ─────────────────────────────────────────────
-- Input
-- ─────────────────────────────────────────────

hl.input = {
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
}

hl.cursor = {
    no_hardware_cursors = true,
}

-- ─────────────────────────────────────────────
-- General
-- ─────────────────────────────────────────────

hl.general = {
    gaps_in  = 5,
    gaps_out = 5,
    border_size = 1,
    ["col.active_border"]   = "$green",
    ["col.inactive_border"] = "$sapphire",
    layout = "dwindle",
    allow_tearing = false,
}

-- ─────────────────────────────────────────────
-- Decoration
-- ─────────────────────────────────────────────

hl.decoration = {
    rounding = 0,
    blur = {
        enabled  = true,
        size     = 10,
        passes   = 3,
        vibrancy = 0.2,
    },
}

-- ─────────────────────────────────────────────
-- Animations
-- ─────────────────────────────────────────────

hl.bezier = {
    { name = "bounce",    points = { 0.34, 1.56, 0.64, 1   } },
    { name = "rubber",    points = { 0.22, 1.2,  0.36, 1   } },
    { name = "overshoot", points = { 0.05, 0.9,  0.1,  1.1 } },
}

hl.animation = {
    enabled = true,
    { target = "windowsIn",   enabled = true, speed = 6, curve = "bounce",    style = "popin 80%" },
    { target = "windowsOut",  enabled = true, speed = 5, curve = "rubber",    style = "popin 80%" },
    { target = "windowsMove", enabled = true, speed = 5, curve = "bounce"                         },
    { target = "workspaces",  enabled = true, speed = 6, curve = "overshoot", style = "slide"     },
    { target = "fade",        enabled = true, speed = 5, curve = "overshoot"                      },
    { target = "border",      enabled = true, speed = 8, curve = "rubber"                         },
}

-- ─────────────────────────────────────────────
-- Layouts
-- ─────────────────────────────────────────────

hl.dwindle = {
    preserve_split = true,
}

hl.master = {
    new_status = "master",
}

-- ─────────────────────────────────────────────
-- Misc
-- ─────────────────────────────────────────────

hl.misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo   = true,
}

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

hl.layerrule = {
    { rule = "blur false", match = "match:namespace ^noctalia-background.*"   },
    { rule = "blur false", match = "match:namespace ^noctalia-bar-content.*"  },
    { rule = "blur false", match = "match:namespace ^noctalia-bar-exclusion.*"},
    { rule = "blur false", match = "match:title slurp"                        },
}

-- ─────────────────────────────────────────────
-- Window rules
-- ─────────────────────────────────────────────

hl.windowrule = {
    { rule = "float on",             match = "match:class ^(.*Microsoft.*)$" },
    { rule = "fullscreen_state 0 0", match = "match:class ^(.*Microsoft.*)$" },
    { rule = "persistent_size on",   match = "match:class ^(.*Microsoft.*)$" },
    { rule = "opacity 1.0 1.0",      match = "match:class .*"                },
}

-- ─────────────────────────────────────────────
-- Keybindings
-- ─────────────────────────────────────────────

-- Screenshots
bind("Print", hl.dsp.exec_cmd("grimblast copy area"))
bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copy active"))

-- Resize submap
-- bind(mainMod.. "+ SHIFT + R", "submap", "resize")
-- hyprland.submap("resize", function()
--     binde("",      "right", "resizeactive",  "10 0")
--     binde("",      "left",  "resizeactive", "-10 0")
--     binde("",      "up",    "resizeactive",  "0 -10")
--     binde("",      "down",  "resizeactive",  "0 10")
--     binde("SHIFT", "right", "resizeactive",  "50 0")
--     binde("SHIFT", "left",  "resizeactive", "-50 0")
--     binde("SHIFT", "up",    "resizeactive",  "0 -50")
--     binde("SHIFT", "down",  "resizeactive",  "0 50")
--     bind("",       "escape", "submap", "reset")
-- end)

-- Media / volume / brightness
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. " volume increase"))
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. " volume decrease"))
bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. " volume muteOutput"))
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. " brightness increase"))
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. " brightness decrease"))
bind("XF86AudioPlay",         hl.dsp.exec_cmd(ipc .. " media playPause"))
-- bind("XF86AudioPlayPause",    hl.dsp.exec_cmd(ipc .. " media playPause"))
bind("XF86AudioNext",         hl.dsp.exec_cmd(ipc .. " media next"))

-- Window management
bind(mainMod .. "+ RETURN", hl.dsp.exec_cmd(terminal))
bind(mainMod .. "+ SHIFT + Q", hl.dsp.window.close())
bind(mainMod .. "+ M",      hl.dsp.exec_cmd("pkill Hyprland"))
bind(mainMod .. "+ D",      hl.dsp.exec_cmd(menu))
bind(mainMod .. "+ SPACE",  hl.dsp.window.float({ action = "toggle" }))
bind(mainMod .. "+ P",      hl.dsp.window.pseudo())
bind(mainMod .. "+ W",      hl.dsp.exec_cmd('hyprctl keyword general:layout "$(hyprctl getoption general:layout | grep -q \'dwindle\' && echo \'master\' || echo \'dwindle\')"'))
bind(mainMod .. "+ F",      hl.dsp.window.fullscreen())
bind(mainMod .. "+ SHIFT + I",      hl.dsp.exec_cmd("pkill -SIGUSR1 ie-r"))

-- Focus (arrows + hjkl)
bind(mainMod .. "+ left",  hl.dsp.focus({ direction = "left" }))
bind(mainMod .. "+ right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. "+ up",    hl.dsp.focus({ direction = "up" }))
bind(mainMod .. "+ down",  hl.dsp.focus({ direction = "down" }))
bind(mainMod .. "+ h",     hl.dsp.focus({ direction = "left" }))
bind(mainMod .. "+ l",     hl.dsp.focus({ direction = "right" }))
bind(mainMod .. "+ k",     hl.dsp.focus({ direction = "up" }))
bind(mainMod .. "+ j",     hl.dsp.focus({ direction = "down" }))

-- Move windows (arrows + hjkl)
bind(mainMod .. "+ SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
bind(mainMod .. "+ SHIFT + right", hl.dsp.window.move({ direction = "right"}))
bind(mainMod .. "+ SHIFT + up",    hl.dsp.window.move({ direction = "up"}))
bind(mainMod .. "+ SHIFT + down",  hl.dsp.window.move({ direction = "down"}))
bind(mainMod .. "+ SHIFT + h",     hl.dsp.window.move({ direction = "left"}))
bind(mainMod .. "+ SHIFT + l",     hl.dsp.window.move({ direction = "right"}))
bind(mainMod .. "+ SHIFT + k",     hl.dsp.window.move({ direction = "up"}))
bind(mainMod .. "+ SHIFT + j",     hl.dsp.window.move({ direction = "down"}))

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
