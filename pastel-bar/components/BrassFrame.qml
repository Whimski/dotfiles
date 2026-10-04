import QtQuick
import QtQuick.Shapes
import ".."

// A restrained steampunk window frame to lay over a panel (anchors.fill it; it
// takes no input). A single brass outline following the panel's `radius`, a dim
// offset "shadow" rail along part of the top-left and bottom-right edges, and an
// ornament seated on each rounded corner.
//   corners: [tl, tr, br, bl], each "screw" | "cross" | "cog" | "none"
//   plate:   "top" | "bottom" | "none" — a link plate riding that edge's centre
// `spin` turns the corner cogs (deg).
//
// `build` (0..1) assembles it — bind the panel's master reveal to it and opening
// builds the frame while closing takes it apart in exact reverse:
//   0.00–0.42  each straight edge draws outward from its middle
//   0.32–0.62  the corner arcs sweep in from both edges until they meet
//   0.55–0.90  an ornament lands where they meet: screws drop in and screw
//              themselves home, cogs spin in from nothing (corners staggered)
//   0.62–0.92  the link plate slides out of its edge
//   0.70–1.00  the dim shadow rails run out along their edges
// Draws nothing outside steampunk mode.
Item {
    id: frame
    property color color: Theme.accent
    property real radius: 16
    property real line: 1.5
    property var corners: ["screw", "cog", "screw", "screw"]
    property string plate: "none"
    property bool rail: true
    property real railGap: 4
    property real spin: 0
    property real build: 1

    visible: Theme.steampunk && build > 0.001

    function seg(a, b) { return Math.max(0, Math.min(1, (build - a) / (b - a))) }
    readonly property real edgeP: Theme.easeOutCubic(seg(0.0, 0.42))
    readonly property real arcP: Theme.easeOutCubic(seg(0.32, 0.62))
    readonly property real plateP: Theme.easeOutBack(seg(0.62, 0.92), 1.6)
    readonly property real railP: Theme.easeOutCubic(seg(0.70, 1.0))

    readonly property color _dim: Theme.alpha(color, 0.5)
    readonly property real _r: Math.min(radius, width / 2, height / 2)
    readonly property real _ar: Math.max(0, _r - line / 2)      // stroke-centre radius
    readonly property real _hl: Math.max(0, width - 2 * _r)     // straight run, top/bottom
    readonly property real _vl: Math.max(0, height - 2 * _r)    // straight run, left/right

    // ---- straight edges, drawn out from their middles ----
    Rectangle {    // top
        x: frame.width / 2 - width / 2; y: 0
        width: frame._hl * frame.edgeP; height: frame.line
        color: frame.color
    }
    Rectangle {    // bottom
        x: frame.width / 2 - width / 2; y: frame.height - frame.line
        width: frame._hl * frame.edgeP; height: frame.line
        color: frame.color
    }
    Rectangle {    // left
        x: 0; y: frame.height / 2 - height / 2
        width: frame.line; height: frame._vl * frame.edgeP
        color: frame.color
    }
    Rectangle {    // right
        x: frame.width - frame.line; y: frame.height / 2 - height / 2
        width: frame.line; height: frame._vl * frame.edgeP
        color: frame.color
    }

    // ---- corner arcs: each corner's two halves sweep toward its 45° midpoint ----
    Shape {
        anchors.fill: parent
        visible: frame.arcP > 0.001 && frame._ar > 0
        preferredRendererType: Shape.CurveRenderer
        component Half: ShapePath {
            property real cx: 0
            property real cy: 0
            property real st: 0
            property real sw: 0
            fillColor: "transparent"
            strokeColor: frame.color
            strokeWidth: frame.line
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: cx; centerY: cy
                radiusX: frame._ar; radiusY: frame._ar
                startAngle: st; sweepAngle: sw
            }
        }
        // TL (180..270), TR (270..360), BR (0..90), BL (90..180)
        Half { cx: frame._r; cy: frame._r; st: 180; sw: 45 * frame.arcP }
        Half { cx: frame._r; cy: frame._r; st: 270; sw: -45 * frame.arcP }
        Half { cx: frame.width - frame._r; cy: frame._r; st: 270; sw: 45 * frame.arcP }
        Half { cx: frame.width - frame._r; cy: frame._r; st: 360; sw: -45 * frame.arcP }
        Half { cx: frame.width - frame._r; cy: frame.height - frame._r; st: 0; sw: 45 * frame.arcP }
        Half { cx: frame.width - frame._r; cy: frame.height - frame._r; st: 90; sw: -45 * frame.arcP }
        Half { cx: frame._r; cy: frame.height - frame._r; st: 90; sw: 45 * frame.arcP }
        Half { cx: frame._r; cy: frame.height - frame._r; st: 180; sw: -45 * frame.arcP }
    }

    // ---- shadow rails: run out along part of each edge, clear of the corners ----
    Rectangle {    // top, from the left
        visible: frame.rail
        x: frame._r + 6; width: frame.width * 0.32 * frame.railP
        y: -frame.railGap; height: Math.max(1, frame.line * 0.7)
        radius: height / 2; color: frame._dim
    }
    Rectangle {    // left, from the top
        visible: frame.rail
        x: -frame.railGap; width: Math.max(1, frame.line * 0.7)
        y: frame._r + 6; height: frame.height * 0.22 * frame.railP
        radius: width / 2; color: frame._dim
    }
    Rectangle {    // bottom, from the right
        visible: frame.rail
        width: frame.width * 0.32 * frame.railP
        x: frame.width - frame._r - 6 - width
        y: frame.height + frame.railGap - height; height: Math.max(1, frame.line * 0.7)
        radius: height / 2; color: frame._dim
    }
    Rectangle {    // right, from the bottom
        visible: frame.rail
        x: frame.width + frame.railGap - width; width: Math.max(1, frame.line * 0.7)
        height: frame.height * 0.22 * frame.railP
        y: frame.height - frame._r - 6 - height
        radius: width / 2; color: frame._dim
    }

    LinkPlate {
        visible: frame.plate !== "none" && frame.plateP > 0.01
        width: Math.min(64, frame.width * 0.24); height: 9
        x: (frame.width - width) / 2
        y: (frame.plate === "top" ? 0 : frame.height) - height / 2
           + (frame.plate === "top" ? -1 : 1) * (1 - frame.plateP) * 8
        scale: 0.4 + 0.6 * frame.plateP
        opacity: Math.min(1, frame.plateP * 2)
        color: frame.color
        rail: true
        line: frame.line * 0.9
    }

    // ---- corner ornaments, seated on each arc's midpoint ----
    Repeater {
        model: 4
        Item {
            id: corner
            required property int index
            readonly property string kind: frame.corners[index] || "none"
            readonly property bool atRight: index === 1 || index === 2
            readonly property bool atBottom: index >= 2
            // TL, TR, BR, BL land in turn
            readonly property real p: frame.seg(0.55 + index * 0.04, 0.78 + index * 0.04)
            readonly property real off: frame._r - frame._ar * Math.SQRT1_2
            visible: kind !== "none" && p > 0
            width: 0; height: 0
            x: atRight ? frame.width - off : off
            y: atBottom ? frame.height - off : off

            Screw {
                visible: corner.kind === "screw" || corner.kind === "cross"
                kind: corner.kind === "cross" ? "cross" : "slot"
                size: 11
                x: -width / 2
                y: -height / 2 - (1 - Theme.easeOutCubic(corner.p)) * 12
                scale: Theme.easeOutBack(corner.p, 2.2)
                opacity: Math.min(1, corner.p * 3)
                color: frame.color
                // a couple of turns as it seats
                slot: (corner.index % 2 ? -45 : 45) - 720 * (1 - Theme.easeOutCubic(corner.p))
            }
            Gear {
                visible: corner.kind === "cog"
                x: -width / 2; y: -height / 2
                teeth: 10; module: 1.8
                tooth: "block"; web: "solid"
                color: frame.color
                rim: Qt.darker(frame.color, 2.4)
                pin: Qt.darker(frame.color, 2.4)
                scale: Theme.easeOutBack(corner.p, 1.8)
                rotation: (corner.index % 2 ? -frame.spin : frame.spin) + corner.index * 9
                          - 240 * (1 - corner.p)
            }
        }
    }
}
