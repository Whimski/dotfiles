import QtQuick
import QtQuick.Shapes
import ".."

// Two equal sprockets joined by a roller chain that actually runs round them.
// The chain is a stadium (two straights + two half-turns); with arc-pitch
// sprockets and a centre distance of `links` pitches, it holds exactly
// teeth + 2*links rollers, and every roller on a half-turn sits in a valley.
// One `drive` angle moves both: sprocket rotation = drive (+ phase), chain
// travel = drive in radians × pitchR, so wheel and chain never slip.
Item {
    id: root
    property int teeth: 10
    property real pitch: 5
    property int links: 5           // straight run between centres, in pitches
    property bool running: true
    property real speed: 40         // deg/s of sprocket rotation
    property real wind: 1           // 0..1 reveal: winds the drive forward into place
    property color color: Theme.alpha(Theme.subtext, 0.5)
    property color accentColor: Theme.accent
    property color chainColor: Theme.alpha(Theme.text, 0.55)
    property color rim: Theme.alpha(Theme.text, 0.22)
    property color pin: Theme.text

    readonly property real pr: teeth * pitch / (2 * Math.PI)
    readonly property real span: links * pitch
    readonly property real tipR: pr + 0.42 * pitch
    readonly property real perim: 2 * span + teeth * pitch
    readonly property int rollers: teeth + 2 * links

    implicitWidth: span + 2 * tipR
    implicitHeight: 2 * tipR

    property real spin: 0
    readonly property real drive: spin - 90 * (1 - wind)
    FrameAnimation {
        running: root.running && root.visible
        onTriggered: root.spin = (root.spin + frameTime * root.speed * root.wind) % 360
    }

    // centre of the left sprocket in local coords
    readonly property real cx: tipR
    readonly property real cy: tipR

    // point on the chain loop at arc length u (clockwise from the top of the left sprocket)
    function _at(u) {
        u = ((u % perim) + perim) % perim
        var t
        if (u < span) return Qt.point(cx + u, cy - pr)
        u -= span
        if (u < Math.PI * pr) { t = -Math.PI / 2 + u / pr; return Qt.point(cx + span + pr * Math.cos(t), cy + pr * Math.sin(t)) }
        u -= Math.PI * pr
        if (u < span) return Qt.point(cx + span - u, cy + pr)
        u -= span
        t = Math.PI / 2 + u / pr
        return Qt.point(cx + pr * Math.cos(t), cy + pr * Math.sin(t))
    }

    // sprockets: valley at -90° (top) when drive = 0, matching roller 0 there
    readonly property real sprocketRot: (drive - 90 - 180 / teeth) % 360
    Sprocket {
        x: root.cx - width / 2; y: root.cy - height / 2
        teeth: root.teeth; pitch: root.pitch
        color: root.color; rim: root.rim; pin: root.pin
        rotation: root.sprocketRot
    }
    Sprocket {
        x: root.cx + root.span - width / 2; y: root.cy - height / 2
        teeth: root.teeth; pitch: root.pitch
        color: root.accentColor; rim: root.rim; pin: root.pin
        rotation: root.sprocketRot
    }

    // link plates: a fat stroked stadium under the rollers
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.alpha(root.chainColor, 0.35)
            strokeWidth: root.pitch * 0.3
            capStyle: ShapePath.RoundCap
            startX: root.cx; startY: root.cy - root.pr
            PathLine { x: root.cx + root.span; y: root.cy - root.pr }
            PathArc { x: root.cx + root.span; y: root.cy + root.pr; radiusX: root.pr; radiusY: root.pr }
            PathLine { x: root.cx; y: root.cy + root.pr }
            PathArc { x: root.cx; y: root.cy - root.pr; radiusX: root.pr; radiusY: root.pr }
        }
    }
    Repeater {
        model: root.rollers
        delegate: Rectangle {
            required property int index
            readonly property point p: root._at(root.drive * Math.PI / 180 * root.pr + index * root.pitch)
            width: root.pitch * 0.44; height: width; radius: width / 2
            x: p.x - width / 2; y: p.y - height / 2
            color: root.chainColor
            antialiasing: true
        }
    }
}
