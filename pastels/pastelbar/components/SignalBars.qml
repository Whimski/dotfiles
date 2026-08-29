import QtQuick
import ".."

// Four ascending WiFi-strength bars filled by `level` (0..1). When inactive
// (wifi off / no connection) the bars fade to a muted subtext colour.
Item {
    id: root
    property real level: 0
    property bool active: true

    implicitWidth: 18
    implicitHeight: 13

    Row {
        id: bars
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: 4
            delegate: Item {
                width: (bars.width - bars.spacing * 3) / 4
                height: bars.height
                required property int index

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: 1
                    height: (parent.index + 1) / 4 * bars.height
                    property bool on: root.level >= (parent.index + 0.5) / 4
                    color: on && root.active
                        ? Theme.accent
                        : Theme.alpha(Theme.subtext, 0.35)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }
    }
}
