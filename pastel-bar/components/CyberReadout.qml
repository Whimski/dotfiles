import QtQuick
import ".."

// A HUD readout for the cyberpunk pill: a spaced-out label over a monospace
// value with a blinking block cursor, and a little bar graph of recent samples
// that scrolls left as each one arrives. `alignRight` mirrors the layout for the
// right-hand side of the pill. `build` (0..1) glitches it on.
Item {
    id: ro
    property string label: ""
    property real value: 0          // 0..1, shown as a percentage
    property var history: []        // 0..1 samples, oldest first
    property bool alignRight: false
    property bool running: true
    property real build: 1
    property color color: Theme.accent

    implicitWidth: 46
    implicitHeight: col.implicitHeight

    function flick(p) { return p <= 0 ? 0 : p >= 1 ? 1 : (Math.floor(p * 8) % 3 === 1 ? 0.15 : 1) }
    opacity: flick(build)

    property bool blink: true
    Timer {
        running: ro.running && ro.visible
        interval: 530; repeat: true
        onTriggered: ro.blink = !ro.blink
        onRunningChanged: if (!running) ro.blink = true
    }

    Column {
        id: col
        width: parent.width
        spacing: 1
        Text {
            width: parent.width
            horizontalAlignment: ro.alignRight ? Text.AlignRight : Text.AlignLeft
            text: ro.label
            color: Theme.alpha(ro.color, 0.75)
            font.pixelSize: Theme.fontSize - 6
            font.weight: Font.Bold
            font.letterSpacing: 2
        }
        Row {
            anchors.right: ro.alignRight ? parent.right : undefined
            spacing: 2
            layoutDirection: ro.alignRight ? Qt.RightToLeft : Qt.LeftToRight
            Text {
                id: valText
                text: Math.round(ro.value * 100) + "%"
                color: Theme.text
                font.family: "monospace"
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.Bold
            }
            Rectangle {    // block cursor
                anchors.verticalCenter: valText.verticalCenter
                width: 5; height: valText.font.pixelSize * 0.8
                color: ro.color
                opacity: ro.blink ? 0.9 : 0
            }
        }
        // history bars, newest at the outer edge, scrolling in from it
        Item {
            width: parent.width; height: 8
            clip: true
            Repeater {
                model: ro.history.length
                Rectangle {
                    required property int index
                    // index 0 = oldest; newest sits nearest the outer edge
                    readonly property int age: ro.history.length - 1 - index
                    readonly property real v: ro.history[index] || 0
                    width: 2
                    height: Math.max(1, 8 * v)
                    y: 8 - height
                    x: ro.alignRight ? age * 3 : parent.width - 2 - age * 3
                    color: Theme.alpha(ro.color, age === 0 ? 1 : 0.35 + 0.5 * (1 - age / 14))
                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
