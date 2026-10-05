import QtQuick
import QtQuick.Shapes
import ".."

// Backdrop HUD hardware for a floating panel — the cyberpunk counterpart of
// PanelMachinery, with the same interface. Lay it over the panel's parent
// (anchors.fill) and declare it BEFORE the panel so it renders behind:
//   rx/ry/rw/rh  the panel's rect in this item's coords
//   reveal       the panel's master open progress — pieces slide out from behind
//                the panel and glitch on with it (and back on close)
//   variant      0..3 picks a different arrangement, so every surface differs
// Pieces (after docs/cyberpunk-refs): a big turning segmented ring half behind
// one side edge and a smaller one on the other, a grid fragment peeking past a
// top corner, a streaming data-noise block under the bottom edge, a node rail
// running off a side, and a column of triangle markers that blink in turn.
// Idles while shown. Draws nothing outside cyberpunk mode.
Item {
    id: h
    property real rx: 0
    property real ry: 0
    property real rw: 0
    property real rh: 0
    property real reveal: 0
    property int variant: 0

    visible: Theme.cyberpunk && reveal > 0.01
    readonly property int v: Math.max(0, Math.min(3, variant))
    readonly property bool flip: v % 2 === 1          // mirror the arrangement
    readonly property real e: Theme.easeOutCubic(reveal)
    function seg(a, b) { return Math.max(0, Math.min(1, (reveal - a) / (b - a))) }
    function flick(p) { return p <= 0 ? 0 : p >= 1 ? 1 : (Math.floor(p * 9) % 3 === 1 ? 0.1 : 1) }

    readonly property color line: Theme.alpha(Theme.accent, 0.55)
    readonly property color dim: Theme.alpha(Theme.accent, 0.3)

    property real spin: 0
    property real phase: 0
    FrameAnimation {
        running: h.visible
        onTriggered: {
            h.spin = (h.spin + frameTime * 7) % 360
            h.phase = (h.phase + frameTime / 2.4) % 1
        }
    }

    // ---- a big HUD ring: segmented outer ring, counter-turning tick ring, a
    // thick partial arc, and an inner dashed ring ----
    component BigRing: Item {
        id: br
        property real size: 200
        property real turn: 0
        property int segs: 6
        width: size; height: size
        readonly property real r: size / 2
        Repeater {
            model: br.segs
            Shape {
                required property int index
                anchors.fill: parent
                rotation: br.turn + index * 360 / br.segs
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: h.line; strokeWidth: 2
                    capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: br.r; centerY: br.r; radiusX: br.r - 1; radiusY: br.r - 1
                                   startAngle: 0; sweepAngle: 360 / br.segs - 9 }
                }
            }
        }
        Item {    // tick ring
            anchors.fill: parent
            rotation: -br.turn * 0.6
            Repeater {
                model: 60
                Rectangle {
                    required property int index
                    readonly property real a: index * Math.PI / 30
                    readonly property real rr: br.r - 9
                    width: index % 5 === 0 ? 7 : 3.5; height: 1
                    x: br.r + rr * Math.cos(a) - width / 2
                    y: br.r + rr * Math.sin(a)
                    rotation: index * 6
                    color: index % 5 === 0 ? h.line : h.dim
                }
            }
        }
        Shape {   // thick partial arc
            anchors.fill: parent
            rotation: br.turn * 1.8
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: h.line; strokeWidth: 5
                capStyle: ShapePath.FlatCap
                PathAngleArc { centerX: br.r; centerY: br.r; radiusX: br.r * 0.72; radiusY: br.r * 0.72
                               startAngle: 0; sweepAngle: 110 }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: h.dim; strokeWidth: 1
                strokeStyle: ShapePath.DashLine; dashPattern: [2, 4]
                PathAngleArc { centerX: br.r; centerY: br.r; radiusX: br.r * 0.6; radiusY: br.r * 0.6
                               startAngle: 0; sweepAngle: 360 }
            }
        }
    }

    // big ring: half behind one side edge, sliding out from behind the panel
    BigRing {
        size: [230, 200, 250, 210][h.v]
        turn: h.spin
        segs: [6, 5, 8, 4][h.v]
        readonly property real cx: h.flip ? h.rx + h.rw - 8 + h.e * 26 : h.rx + 8 - h.e * 26
        x: cx - width / 2
        y: h.ry + h.rh * [0.32, 0.6, 0.45, 0.3][h.v] - height / 2
        opacity: h.flick(h.seg(0.05, 0.5))
    }
    // smaller ring on the other side, lower
    BigRing {
        size: [120, 140, 110, 130][h.v]
        turn: -h.spin * 1.4 + 20
        segs: [3, 4, 5, 3][h.v]
        readonly property real cx: h.flip ? h.rx + 10 - h.e * 30 : h.rx + h.rw - 10 + h.e * 30
        x: cx - width / 2
        y: h.ry + h.rh * [0.75, 0.25, 0.7, 0.72][h.v] - height / 2
        opacity: h.flick(h.seg(0.2, 0.6))
    }

    // grid fragment past a top corner: 3×3 cells with corner ticks and a hatched cell
    Item {
        readonly property real cell: 26
        width: cell * 3; height: cell * 3
        x: h.flip ? h.rx - width * 0.55 : h.rx + h.rw - width * 0.45
        y: h.ry - height * 0.55 - (1 - h.e) * -30
        opacity: h.flick(h.seg(0.3, 0.7))
        Repeater {
            model: 4
            Rectangle { required property int index; x: index * parent.cell; width: 1; height: parent.height; color: h.dim }
        }
        Repeater {
            model: 4
            Rectangle { required property int index; y: index * parent.cell; height: 1; width: parent.width; color: h.dim }
        }
        Repeater {   // corner ticks at every crossing
            model: 16
            Item {
                required property int index
                x: (index % 4) * 26; y: Math.floor(index / 4) * 26
                Rectangle { x: -3; y: -0.5; width: 7; height: 2; color: h.line }
                Rectangle { x: -0.5; y: -3; width: 2; height: 7; color: h.line }
            }
        }
        Item {      // hatched cell
            x: h.flip ? 52 : 0; y: 0; width: 26; height: 26
            clip: true
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    x: -26 + index * 8; y: 13; width: 52; height: 1.5
                    rotation: -45
                    color: h.dim
                }
            }
        }
    }

    // streaming data block under the bottom edge
    DataNoise {
        width: 170; rows: 5
        x: h.flip ? h.rx + h.rw - width - 24 : h.rx + 24
        y: h.ry + h.rh + 12 + (1 - h.e) * -20
        color: Theme.alpha(Theme.accent, 0.6)
        running: h.reveal > 0.99
        opacity: h.flick(h.seg(0.45, 0.85))
    }

    // node rail running off a side, near the bottom
    Item {
        readonly property real len: 150 * Theme.easeOutCubic(h.seg(0.4, 0.95))
        width: 150; height: 8
        x: h.flip ? h.rx - len : h.rx + h.rw
        y: h.ry + h.rh * [0.82, 0.86, 0.12, 0.88][h.v]
        Item {
            width: parent.len; height: parent.height; clip: true
            x: h.flip ? 0 : 0
            Rectangle { y: 3.5; width: 150; height: 1; color: h.line }
            Repeater {
                model: [0.12, 0.3, 0.55, 0.92]
                Rectangle {
                    required property var modelData
                    required property int index
                    x: (h.flip ? 1 - modelData : modelData) * 150 - 3; y: 1
                    width: 6; height: 6
                    color: index === Math.floor(h.phase * 4) ? h.line : "transparent"
                    border.width: 1; border.color: h.line
                }
            }
        }
    }

    // triangle markers: a column of three on the side opposite the big ring,
    // lighting in turn
    Column {
        spacing: 6
        x: h.flip ? h.rx + h.rw + 14 : h.rx - 14 - 12
        y: h.ry + h.rh * [0.45, 0.42, 0.25, 0.5][h.v]
        opacity: h.flick(h.seg(0.55, 0.9))
        Repeater {
            model: 3
            Shape {
                id: tri
                required property int index
                width: 12; height: 11
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: tri.index === Math.floor(h.phase * 3) ? h.line : "transparent"
                    strokeColor: h.line; strokeWidth: 1.2
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline { path: [Qt.point(6, 0.5), Qt.point(11.5, 10.5), Qt.point(0.5, 10.5), Qt.point(6, 0.5)] }
                }
            }
        }
    }
}
