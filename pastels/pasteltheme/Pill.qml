import QtQuick

// Glassy rounded pill / button. Children are laid out in a centered Row (default
// property), so callers write `Pill { IconGlyph {} Text {} }`. Hover + active
// states lift the fill/stroke toward the accent colour.
Rectangle {
    id: pill
    property bool active: false
    property real pad: 9
    property alias hovered: ma.containsMouse
    signal clicked()
    default property alias content: row.data

    implicitHeight: 22
    implicitWidth: row.implicitWidth + pad * 2
    radius: height / 2

    color: (ma.containsMouse || active)
        ? Theme.alpha(Theme.accent, active ? 0.28 : 0.16)
        : Theme.alpha(Theme.current.hover, 0.5)
    border.width: 1
    border.color: active ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass

    scale: ma.pressed ? 0.95 : 1

    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
