import QtQuick
import ".."

// A control-center quick toggle. With steampunk mode off it's the plain solid
// tile; with it on, it's dressed as a steampunk brass button (after the
// "Buttons" reference sheet): a line-art brass body with a porthole holding the
// icon, label + sublabel beside it. On = the porthole fills with brass, the body
// takes a warm accent wash and its outline brightens.
//
// `fitting` picks the body, so a grid of tiles doesn't read as clones:
//   "gears"  — pill with two spoked cogs behind its ends (teeth peek out); they
//              turn a little on toggle, in opposite directions
//   "rails"  — pill under a ticked double rail, a short rail beneath, and a small
//              cog seated on the right shoulder
//   "plate"  — pill with a dim outer shell round its right half, a riveted link
//              plate on the bottom edge and a screw in the right cap
//   "screws" — squared frame, a screw in each corner, a carry handle on top and
//              a knurled grip on the right edge
Item {
    id: tile
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property string fitting: "gears"
    signal clicked()
    signal rightClicked()

    implicitHeight: Theme.steampunk ? 60 : 58

    readonly property bool hot: ma.containsMouse
    readonly property color brass: Theme.accent
    readonly property color engraved: Qt.darker(Theme.accent, 2.6)
    property real lineA: active ? 0.95 : (hot ? 0.75 : 0.5)
    readonly property color line: Theme.alpha(brass, lineA)
    readonly property color dim: Theme.alpha(brass, 0.35)
    Behavior on lineA { NumberAnimation { duration: Theme.animFast } }

    // body box (inset per fitting so the ornaments stay inside the cell)
    readonly property bool pill: fitting !== "screws"
    readonly property real bx: fitting === "gears" ? 7 : 2
    readonly property real by: fitting === "screws" ? 8 : 7
    readonly property real bw: width - bx * 2
    readonly property real bh: height - by - (fitting === "rails" ? 7 : 5)
    readonly property real br: pill ? bh / 2 : 6
    // room the right-hand ornament takes from the text
    readonly property real rightPad: fitting === "gears" ? 24 : fitting === "plate" ? 22 : 14

    // toggle-driven turn for the cogs
    property real turn: active ? 1 : 0
    Behavior on turn { NumberAnimation { duration: Theme.animMed * 1.6; easing.type: Easing.OutBack } }

    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    // ---- steampunk mode off: the plain solid quick-toggle tile ----
    Rectangle {
        anchors.fill: parent
        visible: !Theme.steampunk
        radius: Theme.radiusSm + 2
        color: tile.active ? Theme.alpha(Theme.accent, 0.92)
                           : Theme.alpha(Theme.current.hover, tile.hot ? 0.78 : 0.5)
        border.width: 1
        border.color: tile.active ? "transparent" : Theme.strokeGlass
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
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
    }

    // ---- steampunk mode: the brass button ----
    Item {
        id: brassLook
        anchors.fill: parent
        visible: Theme.steampunk

        // ---- "gears": cogs behind the end caps ----
        Repeater {
            model: tile.fitting === "gears" ? 2 : 0
            Gear {
                required property int index
                teeth: 14; module: (tile.bh / 2 + 5) / 8
                tooth: "block"; web: "spokes"; spokes: 5
                color: Theme.alpha(tile.brass, tile.active ? 0.55 : 0.32)
                rim: Theme.alpha("#000000", 0.35)
                pin: "transparent"
                x: (index === 0 ? tile.bx + tile.br : tile.bx + tile.bw - tile.br) - width / 2
                y: tile.by + tile.bh / 2 - height / 2
                rotation: (index === 0 ? 1 : -1) * tile.turn * (360 / 14) * 1.5 + index * 360 / 28
            }
        }

        // ---- body ----
        // "gears": a near-opaque backing so only the cogs' teeth show past the caps
        Rectangle {
            visible: tile.fitting === "gears"
            x: tile.bx; y: tile.by; width: tile.bw; height: tile.bh
            radius: tile.br
            color: Theme.alpha(Theme.current.panel, 0.94)
        }
        Rectangle {
            id: body
            x: tile.bx; y: tile.by; width: tile.bw; height: tile.bh
            radius: tile.br
            color: tile.active ? Theme.alpha(tile.brass, tile.hot ? 0.3 : 0.22)
                               : Theme.alpha("#000000", tile.hot ? 0.18 : 0.26)
            border.width: 1.5
            border.color: tile.line
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        // ---- "rails": ticked double rail above, short rail below, shoulder cog ----
        Item {
            visible: tile.fitting === "rails"
            anchors.fill: parent
            Rectangle { x: tile.bx + tile.bw * 0.22; width: tile.bw * 0.6; y: tile.by - 4; height: 1.2; color: tile.line }
            Rectangle { x: tile.bx + tile.bw * 0.3; width: tile.bw * 0.44; y: tile.by - 6.5; height: 1; color: tile.dim }
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    x: tile.bx + tile.bw * (index < 3 ? 0.3 : 0.66) + (index % 3) * 4
                    y: tile.by - 6.5; width: 1.4; height: 5
                    color: tile.line
                }
            }
            Rectangle { x: tile.bx + tile.br; width: tile.bw * 0.35; y: tile.by + tile.bh + 3; height: 1.2; color: tile.dim }
            Gear {
                readonly property real a: -Math.PI / 4
                x: tile.bx + tile.bw - tile.br + tile.br * Math.cos(a) - width / 2
                y: tile.by + tile.br + tile.br * Math.sin(a) - height / 2
                teeth: 9; module: 1.5
                tooth: "block"; web: "solid"
                color: tile.line
                rim: Theme.alpha("#000000", 0.35)
                pin: tile.engraved
                rotation: tile.turn * 80
            }
        }

        // ---- "plate": outer shell on the right, link plate below, cap screw ----
        Item {
            visible: tile.fitting === "plate"
            anchors.fill: parent
            Item {
                x: tile.bx + tile.bw * 0.55; y: 0
                width: tile.width - x; height: tile.height
                clip: true
                Rectangle {
                    x: tile.bx - parent.x - 3.5; y: tile.by - 3.5
                    width: tile.bw + 7; height: tile.bh + 7
                    radius: height / 2
                    color: "transparent"
                    border.width: 1; border.color: tile.dim
                }
            }
            LinkPlate {
                width: 34; height: 8
                x: tile.bx + tile.bw * 0.34 - width / 2
                y: tile.by + tile.bh - height / 2
                color: tile.line
                rail: true
                line: 1.2
            }
            Screw {
                size: 10
                x: tile.bx + tile.bw - tile.br - width / 2
                y: tile.by + tile.bh / 2 - height / 2
                color: tile.line
                slot: 45 + tile.turn * 90
            }
        }

        // ---- "screws": corner screws, carry handle, side grip ----
        Item {
            visible: tile.fitting === "screws"
            anchors.fill: parent
            Repeater {
                model: 4
                Screw {
                    required property int index
                    size: 7
                    x: (index % 2 ? tile.bx + tile.bw - 4 - width : tile.bx + 4)
                    y: (index < 2 ? tile.by + 4 : tile.by + tile.bh - 4 - height)
                    color: tile.line
                    slot: index % 2 ? -45 : 45
                }
            }
            // carry handle: a bar on two short posts above the top edge
            Rectangle { x: tile.bx + tile.bw / 2 - 22; width: 44; y: tile.by - 6; height: 1.5; radius: 0.75; color: tile.line }
            Rectangle { x: tile.bx + tile.bw / 2 - 22; width: 1.5; y: tile.by - 6; height: 6; color: tile.line }
            Rectangle { x: tile.bx + tile.bw / 2 + 20.5; width: 1.5; y: tile.by - 6; height: 6; color: tile.line }
            Column {
                x: tile.bx + tile.bw - 9
                y: tile.by + tile.bh / 2 - height / 2
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle { width: 4; height: 1.2; radius: 0.6; color: tile.line }
                }
            }
        }

        // ---- porthole + text ----
        readonly property real portD: 30
        readonly property real portX: tile.pill ? tile.bx + (tile.bh - portD) / 2 + 1 : tile.bx + 10
        Rectangle {
            id: port
            x: brassLook.portX
            y: tile.by + (tile.bh - height) / 2
            width: brassLook.portD; height: width; radius: width / 2
            border.width: 1.5
            border.color: tile.line
            gradient: Gradient {
                GradientStop { position: 0.0; color: tile.active ? Qt.lighter(tile.brass, 1.3) : Theme.alpha("#000000", 0.35) }
                GradientStop { position: 1.0; color: tile.active ? Qt.darker(tile.brass, 1.35) : Theme.alpha("#000000", 0.5) }
            }
            IconGlyph {
                anchors.centerIn: parent
                name: tile.icon
                size: 16
                color: tile.active ? tile.engraved : Theme.text
            }
        }
        Column {
            anchors.verticalCenter: body.verticalCenter
            x: port.x + port.width + 9
            width: tile.bx + tile.bw - tile.rightPad - x
            spacing: 1
            Text {
                text: tile.label
                width: parent.width
                elide: Text.ElideRight
                color: tile.active ? Qt.lighter(tile.brass, 1.25) : Theme.text
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.Bold
                font.letterSpacing: 0.6
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
            Text {
                text: tile.sub
                visible: text !== ""
                width: parent.width
                elide: Text.ElideRight
                color: Theme.subtext
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
