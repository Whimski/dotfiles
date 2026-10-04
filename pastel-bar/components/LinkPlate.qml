import QtQuick
import ".."

// A pill-shaped brass link plate with a rivet in each end and an optional engraved
// centre rail — the recurring fitting on the steampunk dividers and frames.
Item {
    id: plate
    property color color: Theme.accent
    property bool rail: false
    property real line: 1.4

    implicitWidth: 44
    implicitHeight: 9

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(plate.color, 0.14)
        border.width: plate.line
        border.color: plate.color
        antialiasing: true
    }
    Rectangle {
        visible: plate.rail
        anchors.centerIn: parent
        width: parent.width - parent.height * 2.4; height: Math.max(1, plate.line * 0.7)
        color: Theme.alpha(plate.color, 0.6)
    }
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real d: plate.height * 0.42
            width: d; height: d; radius: d / 2
            y: (plate.height - d) / 2
            x: index === 0 ? plate.height / 2 - d / 2 : plate.width - plate.height / 2 - d / 2
            color: plate.color
            antialiasing: true
        }
    }
}
