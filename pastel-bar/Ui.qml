pragma Singleton
import QtQuick

// Shared, transient UI state (not persisted) — toggles for the overlays that are
// driven from the bar or keybinds. Global so the per-screen bars and the single
// overlay windows agree on what's open.
QtObject {
    id: ui
    property bool tuneOpen: false        // settings flyout
    property bool ccOpen: false          // control center flyout
    property string ccFocus: ""          // "", "wifi", "bt" — section to expand on open
    property bool launcherOpen: false    // app launcher / search
    property bool powerOpen: false       // power menu
    property bool weatherOpen: false     // weather flyout
    property bool barExpanded: false     // pill pinned open via keybind (hold-to-expand)

    function openCC(focus) { ccFocus = focus || ""; ccOpen = true }
    function toggleCC() { if (ccOpen) ccOpen = false; else openCC("") }

    // Generic menu dispatch: one entry point so a keybind can open/toggle any named
    // panel (`Ui.togglePanel("settings")`). Add a case here when a new panel — e.g.
    // weather or calendar — lands, and its keybind works with no shell.qml changes.
    function openPanel(name) {
        switch (name) {
        case "cc": case "controlcenter": openCC(""); break
        case "settings": case "tune":    tuneOpen = true; break
        case "launcher":                 launcherOpen = true; break
        case "power":                    powerOpen = true; break
        case "weather":                  weatherOpen = true; break
        }
    }
    function togglePanel(name) {
        switch (name) {
        case "cc": case "controlcenter": toggleCC(); break
        case "settings": case "tune":    tuneOpen = !tuneOpen; break
        case "launcher":                 launcherOpen = !launcherOpen; break
        case "power":                    powerOpen = !powerOpen; break
        case "weather":                  weatherOpen = !weatherOpen; break
        }
    }

    // Any panel opening ends the transient hold-to-expand. These are reached via
    // SUPER+<key> combos, and Hyprland can swallow the SUPER-release "collapse" bind
    // after a combo — without this the pill would stay stuck expanded behind a menu.
    // (Settings also hides the control center — they overlap, so don't stack them.)
    onTuneOpenChanged:     if (tuneOpen)     { ccOpen = false; barExpanded = false }
    onCcOpenChanged:       if (ccOpen)       barExpanded = false
    onLauncherOpenChanged: if (launcherOpen) barExpanded = false
    onPowerOpenChanged:    if (powerOpen)    barExpanded = false
    onWeatherOpenChanged:  if (weatherOpen)  barExpanded = false

    // Safety backstop for hold-to-expand: Hyprland's Alt-release "collapse" bind can be
    // missed after an Alt+<key> combo (Alt+Tab etc.), which would leave the pill stuck
    // open. A normal release still collapses instantly via the release bind; this only
    // catches the missed case, self-healing after a few seconds.
    property Timer _holdSafety: Timer {
        interval: 6000
        onTriggered: ui.barExpanded = false
    }
    onBarExpandedChanged: barExpanded ? _holdSafety.restart() : _holdSafety.stop()
}
