pragma Singleton
import Quickshell
import Quickshell.Io

// Persistent shell settings, stored as JSON under the Quickshell state dir
// (~/.local/state/quickshell/by-id/<id>/settings.json). Read by Theme + the
// Settings panel; written whenever a bound property changes.
Singleton {
    id: root

    property alias theme: adapter.theme        // palette name (see Theme.order)
    property alias mode: adapter.mode          // "light" | "dark" | "auto"
    // Custom palette accents, used when theme === "Custom".
    property alias customPrimary: adapter.customPrimary
    property alias customSecondary: adapter.customSecondary
    // Padding is per-state: the idle ("main") pill and the expanded pill each get
    // their own vertical + horizontal content padding.
    property alias idleVPad: adapter.idleVPad
    property alias idlePad: adapter.idlePad
    property alias expVPad: adapter.expVPad
    property alias expPad: adapter.expPad
    property alias fontSize: adapter.fontSize
    property alias panelOpacity: adapter.panelOpacity    // glass panel / bar background opacity (0..1)
    property alias launcherIcons: adapter.launcherIcons  // show app icons in the launcher list
    property alias launcherSearchFirst: adapter.launcherSearchFirst  // hide app list until a query is typed
    property alias notifToastContent: adapter.notifToastContent  // show body text in the idle toast
    // Apps the pill must not sit on top of: when one of these is the active window
    // on a monitor, that monitor's bar shows no pill at all — including a
    // hold-to-expand, which is otherwise allowed to override even fullscreen. The
    // transient OSD (volume / brightness) still shows, since it only appears in
    // direct response to a keypress. Case-insensitive substrings matched against
    // the window's class or title.
    property alias pillYieldApps: adapter.pillYieldApps
    // MPRIS players to ignore for now-playing / transport (case-insensitive
    // substrings matched against a player's identity / dbus name / desktop entry).
    property alias mediaBlacklist: adapter.mediaBlacklist
    property alias wallpaper: adapter.wallpaper          // global fallback wallpaper
    property alias wallpapers: adapter.wallpapers        // per-screen: { "DP-1": "file://…", … }
    // Weather location (Open-Meteo). One object so lat/lon/city persist atomically
    // (sequential scalar writes race with FileView's watch→reload). Empty when
    // unset → the Weather service auto-detects from IP on first fetch and seeds it.
    // `weatherUnit` is "celsius" | "fahrenheit".
    property alias weatherLoc: adapter.weatherLoc        // { lat, lon, city }
    property alias weatherUnit: adapter.weatherUnit

    // Set the whole location in one write so the JsonAdapter persists it atomically.
    function setWeatherLoc(lat, lon, city) {
        adapter.weatherLoc = { "lat": lat, "lon": lon, "city": ("" + (city || "")) }
    }

    // Add / remove an MPRIS player from the media blacklist. Reassign the whole
    // array so the JsonAdapter notices the change and persists it.
    function addMediaBlacklist(name) {
        var n = ("" + name).trim()
        if (n === "") return
        var cur = adapter.mediaBlacklist || []
        for (var i = 0; i < cur.length; i++)
            if (("" + cur[i]).toLowerCase() === n.toLowerCase()) return
        var next = cur.slice(); next.push(n)
        adapter.mediaBlacklist = next
    }
    function removeMediaBlacklist(name) {
        var cur = adapter.mediaBlacklist || []
        var next = []
        for (var i = 0; i < cur.length; i++)
            if (("" + cur[i]) !== ("" + name)) next.push(cur[i])
        adapter.mediaBlacklist = next
    }

    // Add / remove an app from the pill's yield list (same reassign-whole-array
    // pattern as the media blacklist so the JsonAdapter persists it).
    function addPillYieldApp(name) {
        var n = ("" + name).trim()
        if (n === "") return
        var cur = adapter.pillYieldApps || []
        for (var i = 0; i < cur.length; i++)
            if (("" + cur[i]).toLowerCase() === n.toLowerCase()) return
        var next = cur.slice(); next.push(n)
        adapter.pillYieldApps = next
    }
    function removePillYieldApp(name) {
        var cur = adapter.pillYieldApps || []
        var next = []
        for (var i = 0; i < cur.length; i++)
            if (("" + cur[i]) !== ("" + name)) next.push(cur[i])
        adapter.pillYieldApps = next
    }

    // Resolve the wallpaper for a given output name, falling back to the global one.
    function wallpaperFor(name) {
        var m = adapter.wallpapers || ({})
        if (name && m[name] !== undefined && m[name] !== "") return m[name]
        return adapter.wallpaper
    }
    // Set (or clear, with "") the wallpaper for one output. Reassign the whole
    // object so the JsonAdapter notices the change and persists it.
    function setWallpaperFor(name, path) {
        if (!name) { adapter.wallpaper = path; return }
        var next = {}
        var cur = adapter.wallpapers || ({})
        for (var k in cur) next[k] = cur[k]
        next[name] = path
        adapter.wallpapers = next
    }

    // ---- import / export of all persistent settings ----
    // Last operation feedback for the UI: "" while idle, else a message. `transferOk`
    // distinguishes success from error styling.
    property string transferMsg: ""
    property bool transferOk: false
    readonly property string defaultExportPath: Quickshell.env("HOME") + "/pastelbar-settings.json"

    function _expand(path) {
        var p = ("" + path).trim()
        if (p === "") return ""
        if (p.indexOf("~") === 0) p = Quickshell.env("HOME") + p.substring(1)
        return p
    }

    // Write the whole settings file (pretty-printed) to `path`.
    function exportSettings(path) {
        var p = _expand(path)
        if (p === "") { transferMsg = "Enter a file path"; transferOk = false; return }
        var out
        try { out = JSON.stringify(JSON.parse(fv.text()), null, 2) }
        catch (e) { out = fv.text() }                 // fall back to raw if unparsable
        _xfer.path = p
        _xfer.setText(out + "\n")
        transferMsg = "Exported to " + p
        transferOk = true
    }

    // Load settings from `path`, validate, then apply them atomically (write to the
    // real file + reload the adapter, so every bound property updates at once — no
    // per-key writes that would race the FileView watch/reload).
    function importSettings(path) {
        var p = _expand(path)
        if (p === "") { transferMsg = "Enter a file path"; transferOk = false; return }
        _xfer.path = p
        _xfer.reload()
        if (!_xfer.waitForJob()) { transferMsg = "Cannot read " + p; transferOk = false; return }
        var txt = _xfer.text()
        if (!txt || txt.trim() === "") { transferMsg = "File is empty"; transferOk = false; return }
        try { JSON.parse(txt) }
        catch (e) { transferMsg = "Not valid settings JSON"; transferOk = false; return }
        fv.setText(txt)
        fv.reload()
        transferMsg = "Imported from " + p
        transferOk = true
    }

    // Scratch FileView for reading/writing the export/import file (separate from the
    // live settings view). No watchChanges — we drive it explicitly.
    FileView { id: _xfer }

    FileView {
        id: fv
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First run: no file yet -> materialise it with the defaults below.
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: adapter
            property string theme: "Mint"
            property string mode: "dark"
            property string customPrimary: "#7aa2f7"
            property string customSecondary: "#bb9af7"
            property int idleVPad: 6
            property int idlePad: 14
            property int expVPad: 6
            property int expPad: 18
            property int fontSize: 14
            property real panelOpacity: 0.8
            property bool launcherIcons: true
            property bool launcherSearchFirst: false
            property bool notifToastContent: true
            property var pillYieldApps: []
            property var mediaBlacklist: ["firefox"]
            property string wallpaper: ""
            property var wallpapers: ({})
            property var weatherLoc: ({})   // { lat, lon, city } — empty until set
            property string weatherUnit: "celsius"
        }
    }
}
