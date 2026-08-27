import QtQuick
import ".."

// A control-center quick-toggle tile: icon + label + sublabel, with an active
// (accent-filled) state. Same-directory IconGlyph is used without an import.
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    signal clicked()
    signal rightClicked()

    radius: Theme.radiusSm + 2
    implicitHeight: 58
    color: active ? Theme.alpha(Theme.accent, 0.92)
                  : Theme.alpha(Theme.current.hover, ma.containsMouse ? 0.78 : 0.5)
    border.width: 1
    border.color: active ? "transparent" : Theme.strokeGlass
    // quick press-in + smooth colour transitions
    scale: ma.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 10

        IconGlyph {
            anchors.verticalCenter: parent.verticalCenter
            name: tile.icon
            size: 20
            color: tile.active ? Theme.current.onAccent : Theme.text
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 30
            spacing: 1
            Text {
                text: tile.label
                color: tile.active ? Theme.current.onAccent : Theme.text
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }
            Text {
                text: tile.sub
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                color: tile.active ? Theme.alpha(Theme.current.onAccent, 0.85) : Theme.subtext
                font.pixelSize: Theme.fontSize - 4
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) tile.rightClicked()
            else tile.clicked()
        }
    }
}
