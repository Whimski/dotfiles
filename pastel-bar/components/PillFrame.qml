import QtQuick
import QtQuick.Shapes
import ".."

// The expanded pill's steampunk dressing, assembled live from one master
// progress `t` (the bar's `bloom`) so opening builds it and closing takes it
// apart in exact reverse:
//   0.04–0.40  the top and bottom brass rails draw outward from the centre
//   0.30–0.62  the end caps draw round from both rails until they meet
//   0.55–0.85  a screw drops into each cap's meeting point and screws itself in
//              (the wings hinge there) — the left one a beat before the right
//   0.50–0.80  steam vents open in the bottom rail …
//   0.42–1.00  … and puff a burst of steam that billows out and dissipates
//   0.62–0.92  a riveted link plate slides out under the bottom rail, tick
//              groups click on along the top rail one by one
// Lay it over the pill with anchors.fill; it takes no input. `pulse` (0..1) is a
// per-tick kick from the clockwork that makes the vents breathe a wisp of steam.
Item {
    id: f
    property real t: 0
    property real pulse: 0
    property real inset: 4
    property color color: Theme.alpha(Theme.accent, 0.85)
    property color steam: Theme.alpha(Theme.text, 0.32)
    property real line: 1.6
    property bool showPlate: true

    function seg(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }

    readonly property real r: Math.max(0, height / 2 - inset)
    readonly property real straight: Math.max(0, width - 2 * inset - 2 * r)
    readonly property real railP: Theme.easeOutCubic(seg(0.04, 0.40))
    readonly property real capP: Theme.easeOutCubic(seg(0.30, 0.62))
    readonly property real ventP: Theme.easeOutBack(seg(0.50, 0.80), 2)
    readonly property real plateP: Theme.easeOutBack(seg(0.62, 0.92), 1.6)
    readonly property real puffP: seg(0.42, 1.0)

    // ---- rails: grow outward from the centre ----
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real len: f.straight * f.railP
            x: f.width / 2 - len / 2
            width: len
            y: (index === 0 ? f.inset : f.height - f.inset) - height / 2
            height: f.line
            radius: height / 2
            color: f.color
            visible: len > 0.5
        }
    }
    // a bright spark riding each rail end while it draws
    Repeater {
        model: 4
        Rectangle {
            required property int index
            readonly property real len: f.straight * f.railP
            width: 5; height: 5; radius: 2.5
            x: f.width / 2 + (index % 2 ? 1 : -1) * len / 2 - width / 2
            y: (index < 2 ? f.inset : f.height - f.inset) - height / 2
            color: Qt.lighter(Theme.accent, 1.5)
            opacity: Math.sin(Math.PI * f.railP) * 0.9
            visible: opacity > 0.02
        }
    }

    // ---- end caps: each half-cap sweeps 90° from its rail toward the middle ----
    Shape {
        anchors.fill: parent
        visible: f.capP > 0.001
        preferredRendererType: Shape.CurveRenderer
        component CapArc: ShapePath {
            property real cx: 0
            property real st: 0
            property real sw: 0
            fillColor: "transparent"
            strokeColor: f.color
            strokeWidth: f.line
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: cx; centerY: f.height / 2
                radiusX: f.r; radiusY: f.r
                startAngle: st; sweepAngle: sw
            }
        }
        CapArc { cx: f.inset + f.r; st: 270; sw: -90 * f.capP }
        CapArc { cx: f.inset + f.r; st: 90; sw: 90 * f.capP }
        CapArc { cx: f.width - f.inset - f.r; st: 270; sw: 90 * f.capP }
        CapArc { cx: f.width - f.inset - f.r; st: 90; sw: -90 * f.capP }
    }

    // ---- screws at the cap tips: drop in, then screw home ----
    Repeater {
        model: 2
        Item {
            required property int index
            readonly property real p: f.seg(0.55 + index * 0.06, 0.79 + index * 0.06)
            x: index === 0 ? f.inset : f.width - f.inset
            y: f.height / 2
            Screw {
                size: 10
                x: -width / 2; y: -height / 2 - (1 - Theme.easeOutCubic(parent.p)) * 14
                scale: Theme.easeOutBack(parent.p, 2.2)
                opacity: Math.min(1, parent.p * 3)
                visible: parent.p > 0
                color: Theme.alpha(Theme.accent, 0.95)
                kind: parent.index === 0 ? "slot" : "cross"
                // two and a half turns as it seats
                slot: 45 - 900 * (1 - Theme.easeOutCubic(parent.p))
            }
        }
    }

    // ---- top rail tick groups: click on one by one, from the centre out ----
    Repeater {
        model: 6
        Rectangle {
            required property int index
            // order: inner pair first, then outward
            readonly property int side: index % 2 ? 1 : -1
            readonly property int rank: Math.floor(index / 2)
            readonly property real p: f.seg(0.66 + rank * 0.07, 0.74 + rank * 0.07)
            x: f.width / 2 + side * (f.straight * 0.3 + rank * 4.5) - width / 2
            y: f.inset - height / 2
            width: 1.6; height: 6 * Theme.easeOutBack(p, 3)
            color: f.color
            visible: p > 0
        }
    }

    // ---- link plate slides out from under the bottom rail ----
    LinkPlate {
        width: 46; height: 9
        x: (f.width - width) / 2
        y: f.height - f.inset - height / 2 - (1 - f.plateP) * 8
        scale: 0.4 + 0.6 * f.plateP
        opacity: Math.min(1, f.plateP * 2)
        visible: f.showPlate && f.plateP > 0.01
        color: Theme.alpha(Theme.accent, 0.95)
        rail: true
        line: 1.3
    }

    // ---- steam vents + their bursts ----
    Repeater {
        model: 2
        Item {
            id: vent
            required property int index
            readonly property real dir: index === 0 ? -1 : 1
            x: f.width / 2 + dir * f.straight * 0.32
            y: f.height - f.inset
            // grille: three slots that slide open
            Row {
                x: -width / 2; y: -3
                spacing: 2
                visible: f.ventP > 0.01
                Repeater {
                    model: 3
                    Rectangle {
                        width: 1.6; height: 6 * f.ventP; radius: 0.8
                        color: f.color
                    }
                }
            }
            // opening/closing burst: three puffs billow out and fade
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real q: Math.max(0, Math.min(1, f.puffP * 1.5 - index * 0.22))
                    readonly property real s: 4 + 16 * Theme.easeOutCubic(q)
                    width: s; height: s; radius: s / 2
                    x: vent.dir * (4 + 18 * q + index * 5) - s / 2
                    y: 6 + 20 * Theme.easeOutCubic(q) + index * 3 - s / 2
                    color: f.steam
                    opacity: q > 0 && q < 1 ? Math.sin(Math.PI * q) * (0.9 - index * 0.2) : 0
                    visible: opacity > 0.02
                }
            }
            // tick wisp: a small breath on each escapement tick while open
            Rectangle {
                readonly property real q: 1 - f.pulse
                readonly property real s: 3 + 8 * q
                width: s; height: s; radius: s / 2
                x: vent.dir * 6 * q - s / 2
                y: 4 + 10 * q - s / 2
                color: f.steam
                opacity: f.pulse * 0.7 * f.ventP
                visible: opacity > 0.02
            }
        }
    }
}
