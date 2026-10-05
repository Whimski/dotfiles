import QtQuick
import ".."

// A horizontal steampunk divider: a brass rule with end fittings, an optional
// centre ornament and a dim offset "shadow" rail under its middle.
//   ends:   "dot" | "screw" | "knurl" | "none"
//   centre: "cog" | "plate" | "none"
// `spin` turns the centre cog (deg) — bind it to something if it should move.
// `build` (0..1) assembles it: the centre ornament spins in, the rule runs out
// both ways from it, the end fittings land (screws twisting home), then ticks
// and the shadow rail — bind a reveal to it and closing plays it backwards.
// Cyberpunk mode renders a CyberDivider instead; `cyber` picks its variant.
Item {
    id: div
    property color color: Theme.accent
    property string ends: "screw"
    property string centre: "cog"
    property bool rail: true
    property bool ticks: false
    property real line: 1.5
    property real spin: 0
    property string cyber: "node"

    readonly property color _dim: Theme.alpha(color, 0.5)
    readonly property real _cy: height / 2
    property real build: 1
    function seg(a, b) { return Math.max(0, Math.min(1, (build - a) / (b - a))) }
    readonly property real _centreP: seg(0.0, 0.35)
    readonly property real _ruleP: Theme.easeOutCubic(seg(0.15, 0.7))
    readonly property real _endP: seg(0.6, 0.92)
    readonly property real _tickP: seg(0.5, 0.85)
    readonly property real _railP: Theme.easeOutCubic(seg(0.7, 1.0))
    readonly property real _gap: centre === "cog" ? 15 : 0
    readonly property real _endW: ends === "knurl" ? 12 : ends === "none" ? 0 : 10

    implicitWidth: 240
    implicitHeight: Theme.cyberpunk ? cyberDiv.implicitHeight
                  : !Theme.steampunk ? 1 : centre === "cog" ? 22 : 14

    CyberDivider {
        id: cyberDiv
        anchors.fill: parent
        variant: div.cyber
        color: div.color
        build: div.build
    }
    // neither mode: just the plain glass hairline
    Rectangle {
        visible: !Theme.decorated
        width: parent.width; height: 1
        color: Theme.strokeGlass
    }
    // everything below is the brass divider
    Item {
        anchors.fill: parent
        visible: Theme.steampunk

        // shadow rail: a thinner dim line stepped just below the middle third
        Rectangle {
            visible: div.rail
            width: div.width * 0.4 * div._railP
            x: div.width / 2 - width / 2
            y: div._cy + div.line + 2; height: Math.max(1, div.line * 0.7)
            radius: height / 2
            color: div._dim
        }
        // main rule, broken under a cog so the rule doesn't show through its web
        Repeater {
            model: 2
            Rectangle {
                required property int index
                readonly property real half: (div.width - div._endW - div._gap) / 2 * div._ruleP
                x: index === 0 ? div.width / 2 - div._gap / 2 - half : div.width / 2 + div._gap / 2
                width: half
                y: div._cy - div.line / 2; height: div.line
                radius: height / 2
                color: div.color
            }
        }
        // tick groups at the thirds
        Repeater {
            model: div.ticks ? 6 : 0
            Rectangle {
                required property int index
                readonly property real base: div.width * (index < 3 ? 0.2 : 0.8)
                x: base + (index % 3 - 1) * 5 - width / 2
                width: div.line; height: 7 * Theme.easeOutBack(div._tickP, 2.5)
                y: div._cy - height / 2
                color: div.color
            }
        }

        // end fittings
        Repeater {
            model: div.ends === "none" ? 0 : 2
            Item {
                required property int index
                width: div._endW; height: div._endW
                x: index === 0 ? 0 : div.width - width
                y: div._cy - height / 2
                visible: div._endP > 0
                scale: Theme.easeOutBack(div._endP, 2.2)
                Screw {
                    visible: div.ends === "screw"
                    anchors.fill: parent
                    size: parent.width
                    color: div.color
                    slot: (parent.index === 0 ? 45 : -45) - 540 * (1 - Theme.easeOutCubic(div._endP))
                }
                Rectangle {
                    visible: div.ends === "dot"
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: "transparent"
                    border.width: div.line; border.color: div.color
                    antialiasing: true
                }
                // knurled cap: a short collar of grip lines
                Row {
                    visible: div.ends === "knurl"
                    anchors.centerIn: parent
                    spacing: 1.5
                    Repeater {
                        model: 4
                        Rectangle { width: 1.5; height: 8; color: div.color }
                    }
                }
            }
        }

        // centre ornament
        LinkPlate {
            visible: div.centre === "plate" && div._centreP > 0
            anchors.centerIn: parent
            scale: Theme.easeOutBack(div._centreP, 1.8)
            width: Math.min(52, div.width * 0.22); height: 9
            color: div.color
            rail: true
            line: div.line * 0.9
        }
        Item {
            visible: div.centre === "cog" && div._centreP > 0
            anchors.centerIn: parent
            width: 22; height: 22
            scale: Theme.easeOutBack(div._centreP, 1.8)
            Gear {
                anchors.centerIn: parent
                teeth: 10; module: 1.7
                tooth: "block"; web: "solid"
                color: div.color
                rim: Qt.darker(div.color, 2.4)
                pin: Qt.darker(div.color, 2.4)
                rotation: div.spin - 300 * (1 - Theme.easeOutCubic(div._centreP))
            }
        }
    }
}
