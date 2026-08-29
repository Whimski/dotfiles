import QtQuick
import PastelFM
import pasteltheme

// One entry rendered as a grid tile (icon + name). Emits activate/context signals.
Item {
    id: tile

    property string fileName: ""
    property string iconName: "file"
    property string sizeText: ""
    property bool isDir: false
    property bool isSymlink: false
    property bool selected: false

    signal activated()
    signal clicked(var mouse)
    signal contextRequested(real gx, real gy)

    function glyphFor(name) {
        switch (name) {
        case "folder":  return "📁"
        case "image":   return "🖼️"
        case "audio":   return "🎵"
        case "video":   return "🎬"
        case "pdf":     return "📕"
        case "archive": return "🗜️"
        case "text":    return "📄"
        case "code":    return "🧾"
        default:        return "📄"
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radiusSm
        color: tile.selected ? Theme.current.selection
                             : (hover.hovered ? Theme.current.hover : "transparent")
        border.width: tile.selected ? 1 : 0
        border.color: Theme.current.accent
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyphFor(tile.iconName)
                font.pixelSize: 42
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.fileName + (tile.isSymlink ? " ↗" : "")
                color: Theme.current.text
                font.pixelSize: 12
                elide: Text.ElideMiddle
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: tile.clicked(null)
        onDoubleTapped: tile.activated()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => {
            var g = tile.mapToGlobal(eventPoint.position.x, eventPoint.position.y)
            tile.contextRequested(g.x, g.y)
        }
    }
}
