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
                color: Theme.decorated ? Qt.lighter(Theme.accent, 1.2) : Theme.subtext
                font.family: Theme.decorated ? "monospace" : font.family
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: bar
            width: parent.width
            height: 18

            // ---- plain ----
            Rectangle {
                visible: !Theme.decorated
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
                visible: !Theme.decorated
                width: 16; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: (bar.width - width) * s._frac
                color: Theme.accent
                border.width: 2
                border.color: Theme.current.onAccent
            }

            // ---- cyberpunk: hairline rail, a slanted-end fill bar, a tick ruler
            // under it and a chamfered square knob ----
            Item {
                anchors.fill: parent
                visible: Theme.cyberpunk
                readonly property real cy: Math.round(height / 2)
                Rectangle {    // rail
                    y: parent.cy; width: parent.width; height: 1
                    color: Theme.alpha(Theme.accent, 0.4)
                }
                Chamfer {      // fill, its leading end cut
                    y: parent.cy - 2
                    width: Math.max(0, bar.width * s._frac - 4); height: 5
                    visible: width > 6
                    cut: 4
                    cuts: [false, true, false, false]
                    color: Theme.accent
                }
                Repeater {
                    model: 21
                    Rectangle {
                        required property int index
                        x: (bar.width - 1) * index / 20
                        y: bar.height - height
                        width: 1; height: index % 5 === 0 ? 4 : 2
                        color: Theme.alpha(Theme.accent, index / 20 <= s._frac ? 0.8 : 0.3)
                    }
                }
                Chamfer {      // knob
                    width: 12; height: 12
                    y: parent.cy - height / 2 + 0.5
                    x: (bar.width - width) * s._frac
                    cut: 3
                    color: dragArea.pressed ? Theme.accent : Theme.alpha("#000000", 0.5)
                    strokeWidth: 1.5
                    strokeColor: Theme.accent
                    scale: dragArea.pressed ? 1.25 : (dragArea.containsMouse ? 1.12 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                }
            }

            // ---- steampunk: a brass gauge rail with ticks and a turning cog knob ----
            Item {
                anchors.fill: parent
                visible: Theme.steampunk
                Rectangle {
                    id: rail
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Theme.alpha("#000000", 0.3)
                    border.width: 1; border.color: Theme.alpha(Theme.accent, 0.55)
                    Rectangle {
                        x: 1; y: 1
                        height: parent.height - 2; radius: height / 2
                        width: Math.max(0, (parent.width - 2) * s._frac)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.darker(Theme.accent, 1.3) }
                            GradientStop { position: 1.0; color: Qt.lighter(Theme.accent, 1.2) }
                        }
                    }
                }
                Repeater {
                    model: 11
                    Rectangle {
                        required property int index
                        x: (bar.width - 1) * index / 10
                        y: rail.y + rail.height + 2
                        width: 1; height: index % 5 === 0 ? 4 : 2.5
                        // ticks the fill has passed light up
                        color: Theme.alpha(Theme.accent, index / 10 <= s._frac ? 0.85 : 0.35)
                    }
                }
                Gear {
                    anchors.verticalCenter: parent.verticalCenter
                    x: (bar.width - width) * s._frac
                    teeth: 12; module: 1.25
                    tooth: "block"; web: "solid"; engrave: true
                    color: Theme.accent
                    rim: Theme.alpha("#000000", 0.4)
                    pin: Qt.darker(Theme.accent, 2.4)
                    // turns as the value moves, like a winding knob
                    rotation: s._frac * 540
                    scale: dragArea.pressed ? 1.3 : (dragArea.containsMouse ? 1.15 : 1)
                    Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
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
