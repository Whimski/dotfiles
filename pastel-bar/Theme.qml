pragma Singleton
import QtQuick
import "."

// Central pastel + futuristic theme. Ports pastelfm's palette system (6 palettes,
// each with a light + dark variant) and adds a light/dark/auto mode, futuristic
// glass/glow tokens, and live bar/font metrics bound to the persistent Settings.
QtObject {
    id: theme

    // ---- palette + mode (persisted via Settings) ----
    readonly property string name: Settings.theme
    readonly property string mode: Settings.mode          // "light" | "dark" | "auto"

    // "auto" resolves to dark between 19:00 and 07:00, re-checked each minute.
    // (Swap _isNight() for `gsettings ... color-scheme` via Process if a DE
    // exposes it — the rest of the theme is agnostic to how `dark` is decided.)
    property bool autoDark: _isNight()
    function _isNight() { var h = new Date().getHours(); return h >= 19 || h < 7 }
    readonly property bool dark: mode === "dark" || (mode === "auto" && autoDark)

    property Timer _autoTimer: Timer {
        running: theme.mode === "auto"; interval: 60000; repeat: true
        onTriggered: theme.autoDark = theme._isNight()
    }

    // Qt.darker(x, 1.0) coerces a string or color into a real color so .r/.g/.b
    // are always defined (palette values arrive as strings in some contexts).
    function alpha(c, a) { var k = Qt.darker(c, 1.0); return Qt.rgba(k.r, k.g, k.b, a) }

    // Built-in palettes only — "Custom" is offered separately in the picker.
    readonly property var order: ["Lavender", "Mint", "Peach", "Sky", "Rosé", "Sakura"]

    // Custom palette: user-chosen primary/secondary accents (persisted) over a
    // neutral grey scaffold, so any accent pair reads cleanly in light + dark.
    readonly property color customPrimary: Settings.customPrimary
    readonly property color customSecondary: Settings.customSecondary
    readonly property var _customBase: ({
        light: { bg:"#f5f5f7", surface:"#ffffff", panel:"#ececf0", sidebar:"#eeeef2",
                 text:"#242428", subtext:"#77777f", border:"#e0e0e6", hover:"#e6e6ec",
                 selection:"#dcdce4", danger:"#e0607a", onAccent:"#ffffff" },
        dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                 text:"#ececf0", subtext:"#9a9aa4", border:"#33333b", hover:"#2c2c33",
                 selection:"#3a3a44", danger:"#ee6f8a", onAccent:"#17171b" }
    })
    function _customVariant() {
        var b = dark ? _customBase.dark : _customBase.light
        return { bg:b.bg, surface:b.surface, panel:b.panel, sidebar:b.sidebar,
                 accent:customPrimary, accent2:customSecondary,
                 text:b.text, subtext:b.subtext, border:b.border, hover:b.hover,
                 selection:b.selection, danger:b.danger, onAccent:b.onAccent }
    }

    readonly property var palettes: {
        "Lavender": {
            swatch: "#b8a5e8",
            light: { bg:"#f6f2fc", surface:"#ffffff", panel:"#efe8fa", sidebar:"#f0e9fb",
                     accent:"#9b7ede", accent2:"#c9b6f2", text:"#2e2740", subtext:"#7a6f92",
                     border:"#e3d8f5", hover:"#e9dffb", selection:"#d9c8f6", danger:"#e57ba0",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#b79bf0", accent2:"#6d5a99", text:"#ece7f7", subtext:"#a89dc4",
                     border:"#352d4d", hover:"#2c2c33", selection:"#3a3a44", danger:"#f090b3",
                     onAccent:"#20182f" }
        },
        "Mint": {
            swatch: "#a3ddc6",
            light: { bg:"#eefaf4", surface:"#ffffff", panel:"#e2f5ec", sidebar:"#e6f7ef",
                     accent:"#5cc79b", accent2:"#a7e3ca", text:"#213a30", subtext:"#5f8677",
                     border:"#d2eee1", hover:"#dcf4ea", selection:"#c2ecd9", danger:"#e88aa0",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#71d6ac", accent2:"#3f6b58", text:"#e2f4ec", subtext:"#93bcab",
                     border:"#2a3d34", hover:"#2c2c33", selection:"#3a3a44", danger:"#f094aa",
                     onAccent:"#14261e" }
        },
        "Peach": {
            swatch: "#f5b99f",
            light: { bg:"#fef4ef", surface:"#ffffff", panel:"#fce8df", sidebar:"#fdeade",
                     accent:"#f38a63", accent2:"#f8c0a8", text:"#412c24", subtext:"#93705f",
                     border:"#f6ddd0", hover:"#fce3d7", selection:"#f9cdb9", danger:"#e0709a",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#f59d78", accent2:"#8a5a44", text:"#f6e7df", subtext:"#c8a290",
                     border:"#42332a", hover:"#2c2c33", selection:"#3a3a44", danger:"#ee88aa",
                     onAccent:"#2a1c14" }
        },
        "Sky": {
            swatch: "#a5cdf0",
            light: { bg:"#eef6fd", surface:"#ffffff", panel:"#e0eefb", sidebar:"#e6f1fc",
                     accent:"#5aa6e6", accent2:"#a7cff2", text:"#1f3244", subtext:"#5e7c93",
                     border:"#d3e6f6", hover:"#dcecfa", selection:"#c1ddf5", danger:"#e57ba0",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#6fb4ee", accent2:"#3d6488", text:"#e0eef9", subtext:"#93b3ce",
                     border:"#293747", hover:"#2c2c33", selection:"#3a3a44", danger:"#f090b3",
                     onAccent:"#15242f" }
        },
        "Rosé": {
            swatch: "#f2a9bd",
            light: { bg:"#fdf1f5", surface:"#ffffff", panel:"#fbe3ea", sidebar:"#fce6ed",
                     accent:"#ec7a9c", accent2:"#f6b6c8", text:"#402631", subtext:"#946a78",
                     border:"#f6d5df", hover:"#fbdde6", selection:"#f8c6d4", danger:"#e0607a",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#f090ab", accent2:"#8a4d60", text:"#f6e2e8", subtext:"#cc9aa8",
                     border:"#422e35", hover:"#2c2c33", selection:"#3a3a44", danger:"#ee6f8a",
                     onAccent:"#2a161d" }
        },
        "Sakura": {
            swatch: "#e9b6de",
            light: { bg:"#fbf1fa", surface:"#ffffff", panel:"#f7e4f4", sidebar:"#f9e7f6",
                     accent:"#d987cd", accent2:"#eebbe6", text:"#3b2a3a", subtext:"#8c7189",
                     border:"#f1d6ee", hover:"#f7dff3", selection:"#f0c8ea", danger:"#e5769b",
                     onAccent:"#ffffff" },
            dark:  { bg:"#d91f2029", surface:"#1f1f24", panel:"#26262c", sidebar:"#1c1c21",
                     accent:"#e29dd8", accent2:"#7d5578", text:"#f4e5f2", subtext:"#c49bbf",
                     border:"#3e3047", hover:"#2c2c33", selection:"#3a3a44", danger:"#f088ab",
                     onAccent:"#281a2b" }
        }
    }

    readonly property var current: {
        if (name === "Custom") return _customVariant()
        var p = palettes[name] ? palettes[name] : palettes["Lavender"]
        return dark ? p.dark : p.light
    }
    function swatchOf(paletteName) {
        if (paletteName === "Custom") return customPrimary
        return palettes[paletteName] ? palettes[paletteName].swatch : "#cccccc"
    }

    // ---- convenience colour accessors (track `current`) ----
    readonly property color accent: current.accent
    // Steampunk mode: gears, wings, brass frames, pipes, the phonograph wing and
    // the pill's build-up. Off = the plain glass look. Components branch on this.
    readonly property bool steampunk: Settings.steampunk
    readonly property color text: current.text
    readonly property color subtext: current.subtext
    readonly property color danger: current.danger

    // ---- shape / motion tokens ----
    readonly property int radius: 16
    readonly property int radiusSm: 10
    readonly property int spacing: 12
    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property int animSlow: 420
    readonly property int animDrawer: 520

    // Staggered-reveal helper: given a 0..1 master progress `t`, returns the
    // eased (OutCubic) local progress of the i-th element, where each element
    // starts `step` later than the previous and takes `span` of `t` to land.
    // Pure function — bind opacity/translate to it and animate only `t`.
    function stagger(t, i, step, span) {
        var p = Math.max(0, Math.min(1, (t - i * step) / span))
        return 1 - Math.pow(1 - p, 3)
    }
    // Easing curves as plain functions, for bindings that derive motion from one
    // animated progress value instead of each owning a Behavior.
    function easeOutBack(p, s) {
        p = Math.max(0, Math.min(1, p)); s = s === undefined ? 1.4 : s
        var q = p - 1
        return 1 + (s + 1) * q * q * q + s * q * q
    }
    function easeOutCubic(p) { p = Math.max(0, Math.min(1, p)); return 1 - Math.pow(1 - p, 3) }

    // ---- live metrics (persisted via Settings) ----
    // Per-state padding: the bar applies these around each state's own content, so
    // sizes are content-driven + padding (never clip, never over-space). The idle
    // and expanded pills are tuned separately.
    readonly property int idleVPad: Settings.idleVPad
    readonly property int idlePad: Settings.idlePad
    readonly property int expVPad: Settings.expVPad
    readonly property int expPad: Settings.expPad
    readonly property int fontSize: Settings.fontSize
    // Nominal resting (idle) height — used only for overlay placement.
    readonly property int barHeight: Math.max(20, fontSize + 6) + idleVPad * 2

    // ---- futuristic tokens ----
    // Panel/bar glass opacity is user-tunable (Settings); the dark/light variants
    // nudge slightly around it so both keep a sensible frosted look.
    readonly property real glassOpacity: Math.max(0, Math.min(1,
        Settings.panelOpacity + (dark ? -0.04 : 0.06)))
    readonly property color glassBg: alpha(current.panel, glassOpacity)
    readonly property color glow: current.accent
    readonly property color strokeGlass: alpha(current.border, 0.65)
}
