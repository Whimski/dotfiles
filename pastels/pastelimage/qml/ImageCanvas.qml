import QtQuick
import QtQuick.Effects
import PastelImage
import pasteltheme

// Image display + editor surface. In image-pixel space (`imageItem`): the sharp
// image, one clipped-blurred copy per blur rectangle, a live blur preview while
// dragging, and a pen stroke Canvas — so all edits pan/zoom/rotate with the image
// and export aligned. Blur uses rectangular `clip` on a MultiEffect copy (no mask
// texture needed). Pen is freehand.
Item {
    id: root
    clip: true

    property string tool: "view"          // "view" | "pen" | "blur"
    property color brushColor: "#ff5c8a"
    property int brushSize: 26

    property real zoom: 1
    property real panX: 0
    property real panY: 0

    // edit model: pen  → { tool:"pen",  color, size, pts:[{x,y}…] }
    //             blur → { tool:"blur", x0,y0,x1,y1 } (rectangle)
    property var strokes: []
    property var _cur: null
    property var _sel: null                          // live blur rect {x,y,w,h}
    readonly property bool canUndo: strokes.length > 0
    readonly property var _blurRects: strokes.filter(function (s) { return s.tool === "blur" })

    function fitZoom() {
        if (!img.implicitWidth || !img.implicitHeight) return 1
        var rw = img.implicitWidth, rh = img.implicitHeight
        if (Img.rotation % 180 !== 0) { var t = rw; rw = rh; rh = t }
        return Math.max(0.02, Math.min(root.width / rw, root.height / rh))
    }
    function doFit() { zoom = fitZoom(); panX = 0; panY = 0 }
    function zoomBy(f) { zoom = Math.max(0.05, Math.min(16, zoom * f)) }
    function repaint() { penCanvas.requestPaint() }
    function undo() { if (strokes.length) { strokes = strokes.slice(0, strokes.length - 1); repaint() } }
    function clearEdits() { strokes = []; _sel = null; _cur = null; repaint() }

    signal copiedToClipboard(bool ok)

    function save(path) {
        var p = ("" + path).replace(/^file:\/\//, "")
        imageItem.grabToImage(function (res) { res.saveToFile(p) },
                              Qt.size(img.implicitWidth, img.implicitHeight))
    }

    // Grab the edited image at native resolution and put it on the clipboard.
    function copyToClipboard() {
        imageItem.grabToImage(function (res) { root.copiedToClipboard(Img.copyToClipboard(res)) },
                              Qt.size(img.implicitWidth, img.implicitHeight))
    }

    Rectangle {
        anchors.fill: parent
        color: Settings.background === "dark" ? "#0b0b0d"
               : Settings.background === "checker" ? "transparent"
               : Theme.current.bg
    }
    Canvas {
        anchors.fill: parent
        visible: Settings.background === "checker"
        property int cell: 12
        onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            for (var y = 0; y < height; y += cell)
                for (var x = 0; x < width; x += cell) {
                    ctx.fillStyle = (((x / cell) + (y / cell)) % 2 === 0) ? "#20222a" : "#171920"
                    ctx.fillRect(x, y, cell, cell)
                }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
    }

    // ---- image + edit layers (image-pixel space) ----
    Item {
        id: imageItem
        width: img.implicitWidth
        height: img.implicitHeight
        x: (root.width - width) / 2 + root.panX
        y: (root.height - height) / 2 + root.panY
        scale: root.zoom
        rotation: Img.rotation
        transformOrigin: Item.Center
        visible: Img.hasImage && img.status === Image.Ready

        Image {
            id: img
            source: Img.source
            anchors.fill: parent
            asynchronous: true; cache: true; smooth: true; mipmap: true
            onStatusChanged: if (status === Image.Ready) root.doFit()
        }
        // dedicated (undrawn) source for the blur effect — a MultiEffect can't use
        // an Image that is also being drawn directly.
        Image {
            id: blurSrc
            source: Img.source
            anchors.fill: parent
            visible: false
            cache: true; smooth: true; mipmap: true
        }

        // finalized blur rectangles: a blurred copy of the image clipped to each rect
        Repeater {
            model: root._blurRects
            delegate: Item {
                required property var modelData
                x: Math.min(modelData.x0, modelData.x1)
                y: Math.min(modelData.y0, modelData.y1)
                width: Math.abs(modelData.x1 - modelData.x0)
                height: Math.abs(modelData.y1 - modelData.y0)
                clip: true
                MultiEffect {
                    x: -parent.x; y: -parent.y
                    width: img.width; height: img.height
                    source: blurSrc
                    blurEnabled: true; blur: 1.0; blurMax: 64; autoPaddingEnabled: false
                }
            }
        }
        // live blur preview while dragging
        Item {
            visible: root._sel !== null && root.tool === "blur"
            x: root._sel ? root._sel.x : 0
            y: root._sel ? root._sel.y : 0
            width: root._sel ? root._sel.w : 0
            height: root._sel ? root._sel.h : 0
            clip: true
            MultiEffect {
                x: -parent.x; y: -parent.y
                width: img.width; height: img.height
                source: blurSrc
                blurEnabled: true; blur: 1.0; blurMax: 64; autoPaddingEnabled: false
            }
        }
        // selection outline (keep ~2px on screen regardless of zoom)
        Rectangle {
            visible: root._sel !== null
            x: root._sel ? root._sel.x : 0
            y: root._sel ? root._sel.y : 0
            width: root._sel ? root._sel.w : 0
            height: root._sel ? root._sel.h : 0
            color: Theme.alpha(Theme.accent, 0.10)
            border.width: Math.max(1, 2 / root.zoom)
            border.color: Theme.accent
        }

        // pen strokes
        Canvas {
            id: penCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                ctx.lineCap = "round"; ctx.lineJoin = "round"
                for (var si = 0; si < root.strokes.length; si++) {
                    var s = root.strokes[si]
                    if (s.tool !== "pen") continue
                    ctx.strokeStyle = s.color; ctx.fillStyle = s.color; ctx.lineWidth = s.size
                    var pts = s.pts
                    if (pts.length === 1) {
                        ctx.beginPath(); ctx.arc(pts[0].x, pts[0].y, s.size / 2, 0, 2 * Math.PI); ctx.fill()
                    } else {
                        ctx.beginPath()
                        for (var i = 0; i < pts.length; i++)
                            i === 0 ? ctx.moveTo(pts[i].x, pts[i].y) : ctx.lineTo(pts[i].x, pts[i].y)
                        ctx.stroke()
                    }
                }
            }
        }

        // drawing input (pen/blur)
        MouseArea {
            anchors.fill: parent
            enabled: root.tool !== "view" && Img.hasImage
            preventStealing: true
            cursorShape: Qt.CrossCursor
            onPressed: (m) => root._begin(m.x, m.y)
            onPositionChanged: (m) => { if (pressed) root._extend(m.x, m.y) }
            onReleased: root._end()
        }
    }
    Connections { target: Img; function onCurrentChanged() { root.clearEdits(); root.doFit() } }

    Text {
        anchors.centerIn: parent
        visible: Img.hasImage && img.status !== Image.Ready
        text: img.status === Image.Loading ? "Loading…" : "Couldn't load image"
        color: Theme.current.subtext
        font.pixelSize: 14
    }

    // view pan (view mode only)
    MouseArea {
        anchors.fill: parent
        enabled: root.tool === "view" && Img.hasImage
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.OpenHandCursor
        property real lastX: 0
        property real lastY: 0
        onPressed: (m) => { lastX = m.x; lastY = m.y }
        onPositionChanged: (m) => { if (pressed) { root.panX += m.x - lastX; root.panY += m.y - lastY; lastX = m.x; lastY = m.y } }
        onDoubleClicked: root.zoom = (Math.abs(root.zoom - 1) < 0.01 ? root.fitZoom() : 1)
    }
    WheelHandler { onWheel: (w) => root.zoomBy(w.angleDelta.y > 0 ? 1.15 : 0.87) }

    onWidthChanged: doFit()
    onHeightChanged: doFit()

    // ---- input ----
    function _begin(x, y) {
        if (tool === "blur") {
            _cur = { x0: x, y0: y }                    // pending rect (not committed until release)
            _sel = { x: x, y: y, w: 0, h: 0 }
        } else {
            _cur = { tool: "pen", color: "" + brushColor, size: brushSize, pts: [{ x: x, y: y }] }
            strokes = strokes.concat([_cur])
            repaint()
        }
    }
    function _extend(x, y) {
        if (!_cur) return
        if (tool === "blur") {
            _sel = { x: Math.min(_cur.x0, x), y: Math.min(_cur.y0, y),
                     w: Math.abs(x - _cur.x0), h: Math.abs(y - _cur.y0) }
            _cur.x1 = x; _cur.y1 = y
        } else {
            _cur.pts.push({ x: x, y: y }); repaint()
        }
    }
    function _end() {
        if (tool === "blur" && _cur && _cur.x1 !== undefined
                && Math.abs(_cur.x1 - _cur.x0) >= 3 && Math.abs(_cur.y1 - _cur.y0) >= 3) {
            strokes = strokes.concat([{ tool: "blur", x0: _cur.x0, y0: _cur.y0, x1: _cur.x1, y1: _cur.y1 }])
        }
        _cur = null
        _sel = null
    }
}
