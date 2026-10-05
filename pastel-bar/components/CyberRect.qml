import QtQuick
import ".."

// A drop-in for a plain filled `Rectangle` (color / radius / border.width /
// border.color) that turns chamfered in cyberpunk mode — swap `Rectangle` for
// `CyberRect` and the call site keeps working. `cuts` ([tl, tr, br, bl]) and
// `cut` shape the chamfer (capped at a third of the short side). Children draw
// over the fill as usual. No `gradient`: use a Rectangle + Chamfer for that.
Item {
    id: r
    property color color: "white"
    property real radius: 0
    property var cuts: [true, false, true, false]
    property real cut: 8
    component BorderGroup: QtObject {
        property real width: 0
        property color color: "black"
    }
    readonly property BorderGroup border: BorderGroup {}

    Rectangle {
        anchors.fill: parent
        visible: !Theme.cyberpunk
        color: r.color
        radius: r.radius
        border.width: r.border.width
        border.color: r.border.color
    }
    Chamfer {
        anchors.fill: parent
        visible: Theme.cyberpunk
        cuts: r.cuts
        cut: Math.min(r.cut, r.width / 3, r.height / 3)
        color: r.color
        strokeWidth: r.border.width
        strokeColor: r.border.width > 0 ? r.border.color : "transparent"
    }
}
