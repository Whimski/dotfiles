import QtQuick
import QtQuick.Shapes
import ".."

// A small segmented HUD gauge, after the "circles" row of
// docs/cyberpunk-refs/circles-rulers-letters.jpg:
//   - an outer ring broken into `segments` arcs, slowly turning
//   - a value arc (0..1 over 270°) on a dim track, easing to `value`
//   - an inner ring of dashes turning the other way
//   - a crosshair reticle whose centre dot pulses
// Idles (turns + pulses) while `running`. `build` (0..1) assembles it: the
// arcs sweep in, the dashes and reticle glitch on — bind a reveal.
Item {
    id: hud
    property real value: 0
    property real size: 36
    property int segments: 5
    property bool running: true
    property real build: 1
    property color color: Theme.accent
    // idle turn speed (deg/s); reversed for the inner ring
    property real speed: 22

    width: size; height: size
    readonly property real r: size / 2
    property real spin: 0
    property real pulse: 0
    property real shown: value
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    function seg(a, b) { return Math.max(0, Math.min(1, (build - a) / (b - a))) }
    function flick(p) { return p <= 0 ? 0 : p >= 1 ? 1 : (Math.floor(p * 8) % 3 === 1 ? 0.15 : 1) }

    FrameAnimation {
        running: hud.running && hud.visible
        onTriggered: {
            hud.spin = (hud.spin + frameTime * hud.speed * (0.6 + hud.shown)) % 360
            hud.pulse = (hud.pulse + frameTime * 1.4) % 1
        }
    }

    // ---- outer segmented ring ----
    Repeater {
        model: hud.segments
        Shape {
            required property int index
            anchors.fill: parent
            rotation: hud.spin + index * 360 / hud.segments
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(hud.color, 0.85)
                strokeWidth: 2
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: hud.r; centerY: hud.r
                    radiusX: hud.r - 1; radiusY: hud.r - 1
                    startAngle: 0
                    sweepAngle: (360 / hud.segments - 12) * Theme.easeOutCubic(hud.seg(0, 0.5))
                }
            }
        }
    }

    // ---- value arc on its track (270° gauge, open at the bottom) ----
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(hud.color, 0.22)
            strokeWidth: 3
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: hud.r; centerY: hud.r
                radiusX: hud.r - 6; radiusY: hud.r - 6
                startAngle: 135; sweepAngle: 270 * Theme.easeOutCubic(hud.seg(0.1, 0.6))
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: hud.color
            strokeWidth: 3
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: hud.r; centerY: hud.r
                radiusX: hud.r - 6; radiusY: hud.r - 6
                startAngle: 135
                sweepAngle: Math.max(0.01, 270 * hud.shown * Theme.easeOutCubic(hud.seg(0.3, 0.8)))
            }
        }
    }

    // ---- inner dashes, counter-rotating ----
    Item {
        anchors.fill: parent
        rotation: -hud.spin * 1.6
        opacity: hud.flick(hud.seg(0.4, 0.75))
        Repeater {
            model: 12
            Rectangle {
                required property int index
                readonly property real a: index * Math.PI / 6
                readonly property real rr: hud.r - 10.5
                x: hud.r + rr * Math.cos(a) - width / 2
                y: hud.r + rr * Math.sin(a) - height / 2
                width: 2.5; height: 1
                rotation: index * 30 + 90
                color: Theme.alpha(hud.color, index % 3 === 0 ? 0.9 : 0.45)
            }
        }
    }

    // ---- reticle ----
    Item {
        anchors.fill: parent
        opacity: hud.flick(hud.seg(0.6, 0.95))
        Rectangle { x: hud.r - 4; y: hud.r - 0.5; width: 2.5; height: 1; color: hud.color }
        Rectangle { x: hud.r + 1.5; y: hud.r - 0.5; width: 2.5; height: 1; color: hud.color }
        Rectangle { x: hud.r - 0.5; y: hud.r - 4; width: 1; height: 2.5; color: hud.color }
        Rectangle { x: hud.r - 0.5; y: hud.r + 1.5; width: 1; height: 2.5; color: hud.color }
        Rectangle {
            width: 2; height: 2
            x: hud.r - 1; y: hud.r - 1
            color: hud.color
            opacity: 0.4 + 0.6 * Math.abs(Math.sin(hud.pulse * Math.PI))
        }
    }
}
