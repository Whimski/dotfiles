import QtQuick
import ".."

// A slotted screw head: a brass disc with a dark slot ("slot") or cross ("cross").
// Centre it on a point with `x: px - width / 2`. Part of the steampunk kit
// (Screw, LinkPlate, BrassDivider, BrassFrame, BrassRing) — all pure Theme.accent.
Item {
    id: screw
    property real size: 9
    property color color: Theme.accent
    property string kind: "slot"     // "slot" | "cross"
    property real slot: 45           // deg

    readonly property color _cut: Qt.darker(color, 2.6)

    width: size; height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: screw.color
        border.width: Math.max(0.8, screw.size * 0.1)
        border.color: screw._cut
        antialiasing: true
    }
    Repeater {
        model: screw.kind === "cross" ? 2 : 1
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: screw.size * 0.74; height: Math.max(1, screw.size * 0.16)
            radius: height / 2
            rotation: screw.slot + index * 90
            color: screw._cut
            antialiasing: true
        }
    }
}
