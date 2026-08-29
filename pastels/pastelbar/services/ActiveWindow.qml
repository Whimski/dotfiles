pragma Singleton
import QtQuick
import Quickshell.Hyprland

// Tracks the active window (class + title) on each monitor via Hyprland IPC, so the
// bar can yield (drop below) when its idle pill would otherwise sit on top of a
// configured app.
//
// Hyprland's refresh*() calls are async: the models populate on the *next* event
// loop turn (they emit valuesChanged then), so we must recompute in response to
// those signals — not synchronously after calling refresh. A short timer also
// recomputes after each refresh to catch focus-only changes (same window set, but a
// monitor's active window changed), which update workspace lastIpcObjects, not the
// model's value list.
QtObject {
    id: aw

    // { "HDMI-A-2": { cls: "steam_app_1172620", title: "Sea of Thieves" }, … }
    property var byMonitor: ({})

    // Class + title of the active window on `name` (for the settings quick-add).
    function activeOn(name) { return (name && byMonitor[name]) || null }

    // Does the active window on `name` match any of `patterns` (case-insensitive
    // substring vs the window's class or title)?
    function matches(name, patterns) {
        if (!name || !patterns || patterns.length === 0) return false
        var w = byMonitor[name]
        if (!w) return false
        var hay = ((w.cls || "") + " " + (w.title || "")).toLowerCase()
        for (var i = 0; i < patterns.length; i++) {
            var p = ("" + patterns[i]).trim().toLowerCase()
            if (p !== "" && hay.indexOf(p) !== -1) return true
        }
        return false
    }

    function _recompute() {
        // address → { cls, title }
        var byAddr = {}
        var tls = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var i = 0; i < tls.length; i++) {
            var o = tls[i].lastIpcObject
            if (o && o.address) byAddr[o.address] = { "cls": o.class, "title": o.title }
        }
        // each monitor's active window = its active workspace's lastwindow address
        var map = {}
        var mons = Hyprland.monitors ? Hyprland.monitors.values : []
        for (var j = 0; j < mons.length; j++) {
            var m = mons[j]
            var ws = m.activeWorkspace
            var addr = ws && ws.lastIpcObject ? ws.lastIpcObject.lastwindow : ""
            map[m.name] = byAddr[addr] || null
        }
        byMonitor = map
    }

    // Ask Hyprland for fresh data; recompute lands via the signals / timer below.
    function _refresh() {
        if (Hyprland.refreshToplevels) Hyprland.refreshToplevels()
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        _timer.restart()
    }

    // Recompute once the async refresh has populated the models (next turn); catches
    // focus-only changes that don't alter the model's value list.
    property Timer _timer: Timer { interval: 50; onTriggered: aw._recompute() }

    // Immediate recompute when windows/monitors are added or removed.
    property Connections _cxTop: Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { aw._recompute() }
    }
    property Connections _cxMon: Connections {
        target: Hyprland.monitors
        function onValuesChanged() { aw._recompute() }
    }

    // Any event that can change which window is active on a monitor (or its title).
    property Connections _cx: Connections {
        target: Hyprland
        function onRawEvent(e) {
            switch (e.name) {
            case "activewindow":
            case "activewindowv2":
            case "workspace":
            case "workspacev2":
            case "focusedmon":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "fullscreen":
            case "windowtitle":
            case "windowtitlev2":
                aw._refresh()
            }
        }
    }

    Component.onCompleted: _refresh()
}
