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

    function openCC(focus) { ccFocus = focus || ""; ccOpen = true }
    function toggleCC() { if (ccOpen) ccOpen = false; else openCC("") }
}
