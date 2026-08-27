import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

// App launcher / search. Fullscreen overlay (click-outside + keyboard grab) with
// a centered glass box: search field over a filtered desktop-entry list. Arrow
// keys move the selection, Enter launches, Esc closes.
PanelWindow {
    id: win
    // Keep the surface mapped while the close animation plays.
    readonly property bool open: Ui.launcherOpen
    visible: open || box.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""
    property int sel: 0

    readonly property var results: {
        var model = DesktopEntries.applications
        var apps = model ? model.values : []
        var q = query.toLowerCase().trim()
        var out = []
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (!a || a.noDisplay) continue
            if (q === "") { out.push(a); continue }
            var name = (a.name || "").toLowerCase()
            var comment = (a.comment || "").toLowerCase()
            var generic = (a.genericName || "").toLowerCase()
            // `keywords` is a list<string> in Quickshell — join before matching
            // (calling .toLowerCase() on the array would throw and blank the list).
            var kw = a.keywords
            var kwStr = kw ? (Array.isArray(kw) ? kw.join(" ") : String(kw)).toLowerCase() : ""
            if (name.indexOf(q) >= 0 || comment.indexOf(q) >= 0
                || generic.indexOf(q) >= 0 || kwStr.indexOf(q) >= 0)
                out.push(a)
        }
        out.sort(function (x, y) { return (x.name || "").localeCompare(y.name || "") })
        return out
    }

    onQueryChanged: sel = 0
    onVisibleChanged: if (visible) { query = ""; sel = 0; input.text = ""; input.forceActiveFocus() }

    function launch(i) {
        var a = results[i]
        if (a) { a.execute(); Ui.launcherOpen = false }
    }

    // scrim / click-outside to close
    MouseArea { anchors.fill: parent; onClicked: Ui.launcherOpen = false }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.25)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    GlassPanel {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16
        width: 540
        height: Math.min(74 + list.contentHeight + 16, parent.height * 0.6)
        radius: Theme.radius
        glow: 0.5
        // quick scale + fade + slight rise on open/close
        transformOrigin: Item.Top
        scale: win.open ? 1 : 0.96
        opacity: win.open ? 1 : 0
        transform: Translate { y: win.open ? 0 : -12
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } } }
        Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }   // swallow clicks inside the box

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                id: header
                width: parent.width
                spacing: 10
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: Theme.subtext }
                TextInput {
                    id: input
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 2
                    clip: true
                    onTextChanged: win.query = text
                    Keys.onDownPressed: win.sel = Math.min(win.sel + 1, win.results.length - 1)
                    Keys.onUpPressed: win.sel = Math.max(win.sel - 1, 0)
                    Keys.onReturnPressed: win.launch(win.sel)
                    Keys.onEnterPressed: win.launch(win.sel)
                    Keys.onEscapePressed: Ui.launcherOpen = false
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search…"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize + 2
                        visible: input.text === ""
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.strokeGlass }

            ListView {
                id: list
                width: parent.width
                height: parent.height - header.height - 32
                clip: true
                model: win.results
                currentIndex: win.sel
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 46
                    radius: Theme.radiusSm
                    color: index === win.sel ? Theme.alpha(Theme.accent, 0.2) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Settings.launcherIcons
                            width: visible ? 28 : 0
                            height: 28
                            sourceSize.width: 28; sourceSize.height: 28
                            fillMode: Image.PreserveAspectFit
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (Settings.launcherIcons ? 46 : 8)
                            Text {
                                text: modelData.name || ""
                                color: Theme.text
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.comment || ""
                                visible: text !== ""
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = index
                        onClicked: win.launch(index)
                    }
                }
            }
        }
    }
}
