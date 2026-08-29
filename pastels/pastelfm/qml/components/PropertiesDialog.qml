import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelFM
import pasteltheme

Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: props.isDir ? 560 : 440
    padding: 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var props: ({})
    property var view                // active FileView, for navigation
    property string targetPath: ""
    property var slices: []          // [{ name, size, isDir, frac, color }]
    property double folderTotal: -1  // -1 = not yet computed
    property bool analyzing: false
    property int hovered: -1         // pie slice under the cursor

    function navigateInto(name, isDir) {
        if (!isDir || !view) return
        view.navigate(targetPath + (targetPath.endsWith("/") ? "" : "/") + name)
        close()
    }

    // Pastel slice colours.
    readonly property var palette: [
        "#b8a5e8", "#a3ddc6", "#f5b99f", "#a5cdf0", "#f2a9bd", "#e9b6de",
        "#c9d98f", "#f2d59a", "#9fd8d2", "#d7b3f0"
    ]

    function showFor(p) {
        targetPath = p
        props = FileOps.properties(p)
        slices = []
        folderTotal = -1
        analyzing = false
        open()
        if (props.isDir) {
            analyzing = true
            FileOps.analyzeFolder(p)
        }
    }

    function fmt(bytes) {
        if (bytes < 0) return "—"
        var u = ["B", "KB", "MB", "GB", "TB", "PB"]
        var i = 0, n = bytes
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + u[i]
    }

    Connections {
        target: FileOps
        function onFolderAnalyzed(path, children, total) {
            if (path !== root.targetPath) return   // ignore stale results
            root.analyzing = false
            root.folderTotal = total

            // Build slices, grouping small remainder into "Other".
            var out = []
            var maxSlices = 8
            var accounted = 0
            var count = Math.min(children.length, maxSlices)
            for (var i = 0; i < count; ++i) {
                var c = children[i]
                var frac = total > 0 ? c.size / total : 0
                out.push({ name: c.name, size: c.size, isDir: c.isDir,
                           frac: frac, color: root.palette[i % root.palette.length] })
                accounted += c.size
            }
            if (children.length > maxSlices) {
                var rest = total - accounted
                if (rest > 0)
                    out.push({ name: "Other (" + (children.length - maxSlices) + " items)",
                               size: rest, isDir: false,
                               frac: total > 0 ? rest / total : 0, color: "#c2c2cc" })
            }
            root.slices = out
            pie.requestPaint()
        }
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.current.surface
        border.color: Theme.current.border
        border.width: 1
    }

    component Row2: RowLayout {
        property string k: ""
        property string v: ""
        Layout.fillWidth: true
        spacing: 10
        Text { text: k; color: Theme.current.subtext; font.pixelSize: 13; Layout.preferredWidth: 110 }
        Text { text: v; color: Theme.current.text; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.Wrap }
    }

    contentItem: ColumnLayout {
        spacing: 9
        RowLayout {
            spacing: 10
            Text { text: root.props.isDir ? "📁" : "📄"; font.pixelSize: 30 }
            Text {
                text: root.props.name || ""
                color: Theme.current.text
                font.pixelSize: 17; font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.current.border }
        Row2 { k: "Location"; v: root.props.path || "" }
        Row2 { k: "Type"; v: root.props.isDir ? "Folder" : "File" }
        Row2 {
            k: "Size"
            v: root.props.isDir
               ? (root.analyzing ? "Calculating…" : root.fmt(root.folderTotal))
               : (root.props.sizeText || "")
        }
        Row2 { k: "Modified"; v: root.props.modified || "" }
        Row2 { k: "Owner"; v: (root.props.owner || "") + " : " + (root.props.group || "") }
        Row2 { k: "Permissions"; v: root.props.permissions || "" }
        Row2 { k: "Symlink →"; v: root.props.symlinkTarget || ""; visible: root.props.isSymlink === true }

        // -------- Folder breakdown: pie chart + legend --------
        Rectangle {
            Layout.fillWidth: true
            visible: root.props.isDir === true
            height: 1; color: Theme.current.border
        }
        Text {
            visible: root.props.isDir === true
            text: "Contents by size"
            color: Theme.current.subtext
            font.pixelSize: 12; font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }

        RowLayout {
            visible: root.props.isDir === true
            Layout.fillWidth: true
            spacing: 16

            // Pie
            Item {
                id: pieBox
                Layout.preferredWidth: 170
                Layout.preferredHeight: 170

                // Which slice is under a given point? -1 if outside the ring.
                function sliceAt(px, py) {
                    var cx = width / 2, cy = height / 2
                    var r = Math.min(cx, cy) - 4
                    var dx = px - cx, dy = py - cy
                    var dist = Math.sqrt(dx * dx + dy * dy)
                    if (dist > r || dist < r * 0.52) return -1
                    var a = Math.atan2(dy, dx) + Math.PI / 2   // 0 at top, clockwise
                    if (a < 0) a += 2 * Math.PI
                    var frac = a / (2 * Math.PI)
                    var acc = 0
                    for (var i = 0; i < root.slices.length; ++i) {
                        acc += root.slices[i].frac
                        if (frac <= acc) return i
                    }
                    return root.slices.length - 1
                }

                Canvas {
                    id: pie
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2
                        var r = Math.min(cx, cy) - 4
                        if (root.analyzing || root.slices.length === 0) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.fillStyle = Theme.current.panel
                            ctx.fill()
                            return
                        }
                        var start = -Math.PI / 2
                        for (var i = 0; i < root.slices.length; ++i) {
                            var s = root.slices[i]
                            var ang = s.frac * 2 * Math.PI
                            if (ang <= 0) continue
                            // Pop the hovered slice out slightly.
                            var ox = 0, oy = 0
                            if (i === root.hovered) {
                                var mid = start + ang / 2
                                ox = Math.cos(mid) * 5; oy = Math.sin(mid) * 5
                            }
                            ctx.beginPath()
                            ctx.moveTo(cx + ox, cy + oy)
                            ctx.arc(cx + ox, cy + oy, r, start, start + ang)
                            ctx.closePath()
                            ctx.fillStyle = s.color
                            ctx.fill()
                            start += ang
                        }
                        // Donut hole for a lighter, modern look.
                        ctx.beginPath()
                        ctx.arc(cx, cy, r * 0.52, 0, 2 * Math.PI)
                        ctx.fillStyle = Theme.current.surface
                        ctx.fill()
                    }
                    Connections { target: Theme; function onCurrentChanged() { pie.requestPaint() } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onPositionChanged: {
                        var s = pieBox.sliceAt(mouseX, mouseY)
                        if (s !== root.hovered) { root.hovered = s; pie.requestPaint() }
                        cursorShape = (s >= 0 && root.slices[s].isDir)
                                      ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                    onExited: { root.hovered = -1; pie.requestPaint() }
                    onClicked: {
                        var s = pieBox.sliceAt(mouseX, mouseY)
                        if (s >= 0) root.navigateInto(root.slices[s].name, root.slices[s].isDir)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.analyzing
                    text: "…"
                    color: Theme.current.subtext
                    font.pixelSize: 22
                }

                // Hover tooltip.
                Rectangle {
                    id: tip
                    visible: root.hovered >= 0 && !root.analyzing
                    z: 5
                    radius: 6
                    color: Theme.current.text
                    opacity: 0.92
                    width: tipText.implicitWidth + 16
                    height: tipText.implicitHeight + 10
                    x: Math.max(0, Math.min(pieBox.width - width, pieBox.width / 2 - width / 2))
                    y: -height - 4
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        color: Theme.current.surface
                        font.pixelSize: 11
                        text: root.hovered >= 0 && root.hovered < root.slices.length
                              ? root.slices[root.hovered].name + " · "
                                + root.fmt(root.slices[root.hovered].size) + " · "
                                + Math.round(root.slices[root.hovered].frac * 100) + "%"
                              : ""
                    }
                }
            }

            // Legend
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 5
                Text {
                    visible: !root.analyzing && root.slices.length === 0
                    text: "Empty folder"
                    color: Theme.current.subtext
                    font.pixelSize: 13
                }
                Repeater {
                    model: root.slices
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: 5
                        color: root.hovered === index ? Theme.current.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 8
                            Rectangle { width: 12; height: 12; radius: 3; color: modelData.color }
                            Text {
                                text: (modelData.isDir ? "📁 " : "") + modelData.name
                                color: Theme.current.text
                                font.pixelSize: 12
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.fmt(modelData.size)
                                color: Theme.current.subtext
                                font.pixelSize: 12
                            }
                            Text {
                                text: Math.round(modelData.frac * 100) + "%"
                                color: Theme.current.subtext
                                font.pixelSize: 12
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                        HoverHandler {
                            onHoveredChanged: {
                                root.hovered = hovered ? index : -1
                                pie.requestPaint()
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: modelData.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.navigateInto(modelData.name, modelData.isDir)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.topMargin: 6
            Item { Layout.fillWidth: true }
            PastelButton { text: "Close"; onClicked: root.close() }
        }
    }
}
