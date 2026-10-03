import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Bottom background layer per screen: renders the chosen wallpaper (or the
// palette bg colour as a fallback). Being on the Background layer means the
// frosted panels above it pick up the wallpaper through the compositor's blur.
PanelWindow {
    id: w
    property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    // Own namespace so the glass blur rule (namespace `pastel-bar`) skips the wallpaper.
    WlrLayershell.namespace: "pastel-wallpaper"
    WlrLayershell.layer: WlrLayershell.Background
    color: Theme.current.bg

    readonly property string wp: Settings.wallpaperFor(w.screen ? w.screen.name : "")

    Image {
        anchors.fill: parent
        source: w.wp
        visible: w.wp !== ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
}
