import QtQuick
import QtQuick.Shapes
import ".."

// A clockwork wing, pointing right (mirror with Scale { xScale: -1 } for a left
// wing). An arm pivots on a sprocket hinge; feather blades are riveted along it.
// `spread` 0..1 is the whole reveal: folded = arm tucked down with the feathers
// stacked on it; spread = arm raised and feathers fanned (inner ones droop most,
// like secondaries; the tip feather stays near the arm, like a primary). The
// hinge sprocket is geared to the arm, so unfolding turns it. While `running`, a
// slow sinusoidal flap rides on top, scaled by spread so it settles when folding.
Item {
    id: wing
    property real spread: 1
    property bool running: true
    property int feathers: 6
    property real armLen: 46
    property color armColor: Theme.alpha(Theme.subtext, 0.75)
    property color featherA: Theme.alpha(Theme.accent, 0.55)
    property color featherB: Theme.alpha(Theme.current.accent2, 0.45)
    property color rim: Theme.alpha(Theme.text, 0.25)
    property color rivet: Theme.text
    property real size: 1           // uniform scale (the drawers use a bigger wing)

    // hinge position (where the wing attaches), in the wing's outer coords
    readonly property real hingeX: 9 * size
    readonly property real hingeY: 30 * size

    implicitWidth: 92 * size
    implicitHeight: 60 * size

    property real phase: 0
    FrameAnimation {
        running: wing.running && wing.visible && wing.spread > 0.01
        onTriggered: wing.phase = (wing.phase + frameTime * 2.4) % (2 * Math.PI)
    }
    readonly property real flap: Math.sin(phase) * spread
    readonly property real armAngle: 70 * (1 - spread) - 26 + flap * 7

  Item {
    id: body
    width: 92; height: 60
    scale: wing.size
    transformOrigin: Item.TopLeft

    Item {
        id: arm
        x: 9; y: 30
        rotation: wing.armAngle
        transformOrigin: Item.TopLeft

        Repeater {
            model: wing.feathers
            delegate: Item {
                id: feather
                required property int index
                readonly property real k: index / Math.max(1, wing.feathers - 1)   // 0 inner .. 1 tip
                readonly property real len: 17 + k * 20
                readonly property real h: 4.2
                // relative to the arm: inner plates hang steeply, the tip plate sweeps out
                readonly property real fan: 98 - k * 66
                x: wing.armLen * (0.12 + k * 0.88) - 2
                y: -h
                width: len; height: 2 * h
                transformOrigin: Item.Left
                rotation: (fan + wing.flap * (4 + (wing.feathers - index) * 1.5)) * wing.spread
                z: -index

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: feather.index % 2 ? wing.featherB : wing.featherA
                        strokeColor: wing.rim
                        strokeWidth: 1
                        joinStyle: ShapePath.RoundJoin
                        // narrow quill root widening into a plate with a rounded tip
                        startX: 0; startY: feather.h * 0.55
                        PathLine { x: feather.len * 0.28; y: 0 }
                        PathLine { x: feather.len - feather.h; y: 0 }
                        PathArc { x: feather.len - feather.h; y: 2 * feather.h; radiusX: feather.h; radiusY: feather.h }
                        PathLine { x: feather.len * 0.28; y: 2 * feather.h }
                        PathLine { x: 0; y: feather.h * 1.45 }
                        PathLine { x: 0; y: feather.h * 0.55 }
                    }
                    // spine
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: wing.rim
                        strokeWidth: 1
                        startX: 1; startY: feather.h
                        PathLine { x: feather.len * 0.8; y: feather.h }
                    }
                }
                Rectangle {
                    x: 0.5; y: feather.h - 1.3
                    width: 2.6; height: 2.6; radius: 1.3
                    color: wing.rivet; opacity: 0.8
                }
            }
        }

        // the arm bar, over the feather roots
        Rectangle {
            x: -1; y: -2.6
            width: wing.armLen + 2; height: 5.2; radius: 2.6
            color: wing.armColor
            border.color: wing.rim; border.width: 1
            antialiasing: true
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    x: parent.width * (0.35 + index * 0.25) - 1.2; y: parent.height / 2 - 1.2
                    width: 2.4; height: 2.4; radius: 1.2
                    color: wing.rivet; opacity: 0.7
                }
            }
        }
    }

    // hinge sprocket, geared 3:1 to the arm
    Sprocket {
        x: 9 - width / 2; y: 30 - height / 2
        teeth: 8; pitch: 3.2
        color: Theme.alpha(Theme.subtext, 0.85)
        rim: wing.rim; pin: wing.rivet
        rotation: wing.armAngle * 3
    }
  }
}
