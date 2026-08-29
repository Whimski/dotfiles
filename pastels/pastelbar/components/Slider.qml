import QtQuick
import ".."

// Glassy horizontal slider: a label + value row above a draggable track. Emits
// `moved(value)` continuously while dragging (and on click-to-position). Callers
// bind `value` to their source and persist in the `moved` handler.
Item {
    id: s
    property real from: 0
    property real to: 100
    property real value: 0
    property int decimals: 0
    property string label: ""
    property string suffix: ""
    signal moved(real v)

    implicitHeight: 46
    implicitWidth: 240

    readonly property real _frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Column {
        anchors.fill: parent
        spacing: 7

        Row {
            width: parent.width
            Text {
                text: s.label
                color: Theme.text
                font.pixelSize: Theme.fontSize - 1
                width: parent.width - valLabel.width
                elide: Text.ElideRight
            }
            Text {
                id: valLabel
                text: s.value.toFixed(s.decimals) + s.suffix
                color: Theme.subtext
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: bar
            width: parent.width
            height: 18

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Theme.alpha(Theme.subtext, 0.3)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * s._frac
                    color: Theme.accent
                }
            }
            Rectangle {
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: (bar.width - width) * s._frac
                color: Theme.accent
                border.width: 2
                border.color: Theme.current.onAccent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => s._setFromX(m.x)
                onPositionChanged: (m) => { if (pressed) s._setFromX(m.x) }
            }
        }
    }

    function _setFromX(mx) {
        var t = Math.max(0, Math.min(1, mx / bar.width))
        var v = s.from + t * (s.to - s.from)
        s.value = v
        s.moved(v)
    }
}
