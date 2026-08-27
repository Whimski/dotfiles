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
    property alias notifToastContent: adapter.notifToastContent  // show body text in the idle toast
    property alias wallpaper: adapter.wallpaper          // global fallback wallpaper
    property alias wallpapers: adapter.wallpapers        // per-screen: { "DP-1": "file://…", … }

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
            property bool notifToastContent: true
            property string wallpaper: ""
            property var wallpapers: ({})
        }
    }
}
