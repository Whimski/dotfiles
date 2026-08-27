import QtQuick
import ".."

// MPRIS-reactive audio wave: five bars that bounce while `active` (a player is
// playing) and settle to a flat line otherwise. Purely animated — driven by
// playback state, not real audio levels (see Media.playing).
Item {
    id: wave
    property bool active: false
    property color color: Theme.accent

    implicitWidth: 22
    implicitHeight: 16

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: 5
            delegate: Item {
                width: 3
                height: wave.height
                required property int index

                Rectangle {
                    id: bar
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    radius: 1.5
                    color: wave.color
                    height: 3

                    SequentialAnimation on height {
                        running: wave.active
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 6 + (bar.parent.index % 3) * 3 + 4
                            duration: 260 + bar.parent.index * 70
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 3
                            duration: 240 + bar.parent.index * 60
                            easing.type: Easing.InOutSine
                        }
                    }
                    // Ease back to the flat line when playback stops.
                    Behavior on height {
                        enabled: !wave.active
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
