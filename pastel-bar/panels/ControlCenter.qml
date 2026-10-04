import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The control center: two glass drawers that slide in from opposite screen edges.
// Right: header + quick-toggle tiles + volume/brightness sliders + Wi-Fi /
// Bluetooth / Audio sections + notifications (scrollable when taller than the
// screen). Left: the music wing (MediaWing) — always opens together with the control
// center (an idle "Nothing Playing" card when no player), or alone via Ui.mediaOpen.
PanelWindow {
    id: cc
    // Open on the focused monitor. Only re-targeted while hidden — moving a mapped
    // layer surface would re-create it mid-animation.
    property var _screen: null
    screen: _screen
    Component.onCompleted: _screen = Ui.focusedScreen
    Connections {
        target: Ui
        function onFocusedScreenChanged() { if (!cc.visible) cc._screen = Ui.focusedScreen }
    }
    readonly property bool open: Ui.ccOpen
    readonly property bool mediaShown: Ui.mediaOpen || Ui.ccOpen || peek

    // ---- track-change peek ----
    // A new track pops the music wing open for a few seconds on its own. While
    // only peeking, the window's input is masked to the wing (see `mask`) and it
    // never takes keyboard focus, so nothing else on screen is blocked. Hovering
    // the wing holds it open.
    property bool peek: false
    readonly property bool peekOnly: peek && !Ui.ccOpen && !Ui.mediaOpen
    property string _lastTrack: ""
    property bool _ready: false
    Timer { running: true; interval: 3000; onTriggered: cc._ready = true }   // no pop on startup
    Timer { id: peekTimer; interval: 4500; onTriggered: cc.peek = false }
    // Debounced: title/artist/playing settle over a few signals on a track change.
    Timer {
        id: trackSettle
        interval: 350
        onTriggered: {
            var key = Media.title + "\u0001" + Media.artist
            if (Media.title === "" || key === cc._lastTrack) return
            cc._lastTrack = key
            if (!cc._ready || !Media.playing || Ui.ccOpen || Ui.mediaOpen) return
            cc.peek = true
            if (!wingHover.hovered) peekTimer.restart()
        }
    }
    Connections {
        target: Media
        function onTitleChanged() { trackSettle.restart() }
        function onArtistChanged() { trackSettle.restart() }
        function onPlayingChanged() { trackSettle.restart() }
    }
    Connections {
        target: Ui
        function onCcOpenChanged() { cc.peek = false }
        function onMediaOpenChanged() { cc.peek = false }
    }

    // Master open progress for each drawer. Everything else (slide, fade, the
    // staggered rows) is derived from these, so open and close stay in lockstep.
    // Opening is slow and springy; closing is quicker so it never feels sticky.
    property real ccReveal: open ? 1 : 0
    property real mediaReveal: mediaShown ? 1 : 0
    Behavior on ccReveal { NumberAnimation { duration: cc.open ? Theme.animDrawer + 120 : Theme.animMed + 80; easing.type: Easing.Linear } }
    Behavior on mediaReveal { NumberAnimation { duration: cc.mediaShown ? Theme.animDrawer + 200 : Theme.animMed + 80; easing.type: Easing.Linear } }

    // Stay mapped while the close animation plays out, then unmap.
    visible: ccReveal > 0.001 || mediaReveal > 0.001

    function closeAll() { Ui.ccOpen = false; Ui.mediaOpen = false; cc.peek = false }
    function _stage(i) { return Theme.stagger(cc.ccReveal, i, 0.08, 0.55) }

    // Fullscreen so clicks anywhere outside the panel can dismiss it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: peekOnly ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand
    // Full-window input normally (outside clicks dismiss); just the wing while peeking.
    mask: Region {
        x: cc.peekOnly ? wing.x : 0
        y: cc.peekOnly ? wing.y : 0
        width: cc.peekOnly ? wing.width : cc.width
        height: cc.peekOnly ? wing.height : cc.height
    }

    readonly property int _topMargin: Theme.barHeight + 12

    // Bind the Notifs singleton eagerly so the notification server registers at
    // startup, not only when the flyout first opens.

    // When opened from a bar pill, expand the matching section.
    Connections {
        target: Ui
        function onCcOpenChanged() {
            if (!Ui.ccOpen) return
            inner.wifiOpen = Ui.ccFocus === "wifi"
            inner.btOpen = Ui.ccFocus === "bt"
            inner.audioPickerOpen = Ui.ccFocus === "audio"
        }
    }

    // Ordered list of every hintable action (see HintOverlay below), rebuilt on
    // demand (cheap, and always reflects current visibility of the optional
    // sections).
    function _kbList() {
        var l = []
        l.push({ key: "gear", item: gearIcon, activate: () => { Ui.tuneOpen = !Ui.tuneOpen } })
        l.push({ key: "close", item: closeIcon, activate: () => { Ui.ccOpen = false } })
        l.push({ key: "wifiTile", item: wifiTile, activate: () => Net.setEnabled(!Net.enabled) })
        l.push({ key: "btTile", item: btTile, activate: () => BT.setPowered(!BT.powered) })
        l.push({ key: "audioTile", item: audioTile, activate: () => Audio.toggleMute() })
        l.push({ key: "dndTile", item: dndTile, activate: () => { Notifs.dnd = !Notifs.dnd } })
        if (inner.audioPickerOpen) {
            for (var si = 0; si < Audio.sinks.length; si++) {
                (function (i) { l.push({ key: "sink:" + i, item: picker, activate: () => Audio.setSink(Audio.sinks[i]) }) })(si)
            }
        }
        if (inner.wifiOpen) {
            l.push({ key: "wifi:rescan", item: wifiSec, activate: () => Net.rescan() })
            if (Net.enabled) {
                for (var ni = 0; ni < Net.networks.length; ni++) {
                    (function (i) {
                        l.push({ key: "net:" + i, item: wifiSec, activate: () => {
                            var n = Net.networks[i]
                            var secured = n.security !== undefined && n.security !== 0
                            if (n.connected) Net.disconnect(n)
                            else if (secured) wifiSec.pending = (wifiSec.pending === n ? null : n)
                            else Net.connect(n, "")
                        } })
                    })(ni)
                }
                if (wifiSec.pending)
                    l.push({ key: "net:pw", item: wifiSec, activate: () => wifiSec.pwInput.forceActiveFocus() })
            }
        }
        if (inner.btOpen) {
            l.push({ key: "bt:scan", item: btSec, activate: () => BT.startScan() })
            if (BT.powered) {
                for (var bi = 0; bi < BT.devices.length; bi++) {
                    (function (i) {
                        l.push({ key: "bt:" + i, item: btSec, activate: () => {
                            var d = BT.devices[i]
                            if (d.connected) BT.disconnect(d)
                            else if (d.paired) BT.connect(d)
                            else BT.pair(d)
                        } })
                    })(bi)
                }
            }
        }
        if (Notifs.count > 0) {
            l.push({ key: "notif:clear", item: notifList, activate: () => Notifs.clearAll() })
            for (var nfi = 0; nfi < Notifs.list.length; nfi++) {
                (function (i) {
                    l.push({ key: "notif:" + i, item: notifList, activate: () => Notifs.activate(Notifs.list[i]) })
                })(nfi)
            }
        }
        return l
    }

    // Click anywhere outside the drawers to dismiss them.
    MouseArea {
        anchors.fill: parent
        onClicked: cc.closeAll()
    }

    // Edge vignettes: a soft shade creeps in from whichever side a drawer opens
    // on, so the drawer reads as rising out of the screen edge. Kept below the
    // blur rule's ignore_alpha (0.2) so the shade itself never gets frosted.
    Rectangle {
        anchors.fill: parent
        opacity: Theme.easeOutCubic(cc.ccReveal)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.alpha("#000000", Theme.dark ? 0.18 : 0.12) }
        }
    }
    Rectangle {
        anchors.fill: parent
        opacity: cc.peekOnly ? 0 : Theme.easeOutCubic(cc.mediaReveal)
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha("#000000", Theme.dark ? 0.18 : 0.12) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }

    Item {
        id: kbScope
        anchors.fill: parent
        focus: cc.open || Ui.mediaOpen
        Keys.onPressed: (event) => {
            if (hintOverlay.active) { hintOverlay.handleKey(event); event.accepted = true; return }
            switch (event.key) {
            case Qt.Key_F: if (cc.open) hintOverlay.start(cc._kbList()); break
            case Qt.Key_Escape: cc.closeAll(); break
            // music wing transport
            case Qt.Key_Space: Media.playPause(); break
            case Qt.Key_Left: Media.prev(); break
            case Qt.Key_Right: Media.next(); break
            default: return
            }
            event.accepted = true
        }
    }

    // ---- machinery behind the music wing ----
    // Big translucent cogs peeking out from behind the wing's right edge and from
    // under its bottom edge (running off the screen edge). They ride the wing's
    // slide, wind into place with mediaReveal, and turn while music plays —
    // easing up to speed on play and coasting down to an idle crawl on pause.
    Item {
        id: machinery
        anchors.fill: parent
        // shown on a track-change peek too — the cogs come with the wing
        opacity: Math.min(1, cc.mediaReveal * 2)
        visible: Theme.steampunk && opacity > 0.01
        transform: Translate { x: (1 - wing.e) * -(wing.width + 40) }

        property real spin: 0
        property real speed: Media.playing ? 16 : 2.5
        Behavior on speed { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
        readonly property real drive: spin - 70 * (1 - Theme.easeOutCubic(cc.mediaReveal))
        FrameAnimation {
            running: machinery.visible
            onTriggered: machinery.spin = (machinery.spin + frameTime * machinery.speed) % 36000
        }
        readonly property var tints: [Theme.alpha(Theme.subtext, 0.34),
                                      Theme.alpha(Theme.current.accent2, 0.3),
                                      Theme.alpha(Theme.accent, 0.26)]

        GearTrain {
            id: sideTrain
            module: 5
            spec: [{ teeth: 28, tooth: "block", web: "spokes", spokes: 6, engrave: true },
                   { teeth: 13, ang: 18, web: "holes", spokes: 4 },
                   { teeth: 20, ang: 85, tooth: "round", web: "spokes", spokes: 5, twist: 24 },
                   { teeth: 9, on: 2, ang: 20, tooth: "block", web: "solid" },
                   { teeth: 24, on: 2, ang: 150, web: "rings" }]
            colors: machinery.tints
            drive: machinery.drive
            x: wing.x + wing.width - 6 - anchor0.x
            y: wing.y + 120 - anchor0.y
        }
        GearTrain {
            id: underTrain
            module: 5
            spec: [{ teeth: 34, tooth: "block", web: "spokes", spokes: 8, engrave: true },
                   { teeth: 15, ang: 10, tooth: "round", web: "holes", spokes: 5 },
                   { teeth: 22, ang: 175, on: 0, web: "spokes", spokes: 6, twist: -20 }]
            colors: [machinery.tints[1], machinery.tints[0], machinery.tints[2]]
            drive: -machinery.drive * 0.8 + 7
            x: wing.x + 110 - anchor0.x
            y: wing.y + wing.height + 4 - anchor0.y
        }

        // line-art plumbing round the cogs (after the "Decor elements" sheet):
        // arc rails hugging the big wheels, pipes run off the wing's edges
        readonly property color line: Theme.alpha(Theme.accent, 0.62)
        BrassArc {
            readonly property point c: cc.wheelAt(sideTrain, 0)
            cx: c.x; cy: c.y; r: cc.tipOf(sideTrain, 0) + 10
            start: -78; sweep: 112
            twin: true
            color: machinery.line
        }
        BrassArc {
            readonly property point c: cc.wheelAt(underTrain, 0)
            cx: c.x; cy: c.y; r: cc.tipOf(underTrain, 0) + 10
            start: 25; sweep: 120
            ends: "dot"
            color: machinery.line
        }
        BrassPipe {
            anchors.fill: parent
            readonly property real endY: cc.wheelAt(sideTrain, 0).y + 40
            points: [[wing.x + wing.width, wing.y + 34],
                     [wing.x + wing.width + 190, wing.y + 34],
                     [wing.x + wing.width + 190, endY]]
            color: machinery.line
        }
        BrassPipe {
            anchors.fill: parent
            readonly property real bx: wing.x + wing.width - 64
            readonly property real by: wing.y + wing.height
            points: [[bx, by], [bx, by + 74], [bx + 150, by + 74], [bx + 150, by + 120]]
            bore: 8
            color: machinery.line
        }
    }

    // wheel i's centre (parent coords) and tip radius, for hanging rails and
    // pipes off a GearTrain
    function wheelAt(t, i) { var w = t.train.wheels[i]; return Qt.point(t.x + w.x, t.y + w.y) }
    function tipOf(t, i) { return t.module * (t.spec[i].teeth / 2 + 1) }

    // ---- left: music wing ----
    MediaWing {
        id: wing
        reveal: cc.mediaReveal
        anchors.top: parent.top
        anchors.topMargin: cc._topMargin
        anchors.left: parent.left
        anchors.leftMargin: 14
        width: 340
        height: Math.min(implicitHeight, cc.height - cc._topMargin - 24)
        // Slides in from past the left edge with a gentle overshoot, tilting
        // slightly as it lands.
        readonly property real e: Theme.easeOutBack(cc.mediaReveal, 1.1)
        opacity: Math.min(1, cc.mediaReveal * 2.5)
        visible: cc.mediaReveal > 0.001
        transformOrigin: Item.Left
        transform: [
            Translate { x: (1 - wing.e) * -(wing.width + 40) },
            Rotation { origin.x: 0; origin.y: wing.height / 2; axis { x: 0; y: 1; z: 0 }
                       angle: (1 - Theme.easeOutCubic(cc.mediaReveal)) * 24 }
        ]
        MouseArea { anchors.fill: parent; z: -1 }   // swallow background clicks
        HoverHandler {
            id: wingHover
            onHoveredChanged: if (cc.peek) { if (hovered) peekTimer.stop(); else peekTimer.restart() }
        }
    }

    // ---- machinery behind the control center ----
    // The CC's own clockwork, built differently from the wing's: a saw-toothed
    // train peeking out of the drawer's left edge, a ring-engraved one under its
    // bottom, arc rails and pipes. Rides the drawer's slide, winds in with
    // ccReveal and crawls round while open.
    Item {
        id: ccMachinery
        anchors.fill: parent
        opacity: Math.min(1, cc.ccReveal * 2)
        visible: Theme.steampunk && opacity > 0.01
        transform: Translate { x: (1 - ccPanel.e) * (ccPanel.width + 40) }

        property real spin: 0
        FrameAnimation {
            running: ccMachinery.visible
            onTriggered: ccMachinery.spin = (ccMachinery.spin + frameTime * 5) % 36000
        }
        readonly property real drive: spin + 90 * (1 - Theme.easeOutCubic(cc.ccReveal))
        readonly property color line: Theme.alpha(Theme.accent, 0.62)

        GearTrain {
            id: ccSideTrain
            module: 5
            spec: [{ teeth: 30, tooth: "saw", web: "spokes", spokes: 7, twist: 18 },
                   { teeth: 12, ang: 165, tooth: "round", web: "solid", engrave: true },
                   { teeth: 22, ang: 115, on: 0, web: "holes", spokes: 6 },
                   { teeth: 10, ang: 195, on: 2, tooth: "block", web: "solid" }]
            colors: [machinery.tints[2], machinery.tints[0], machinery.tints[1]]
            drive: ccMachinery.drive
            x: ccPanel.x + 8 - anchor0.x
            y: ccPanel.y + ccPanel.height * 0.5 - anchor0.y
        }
        GearTrain {
            id: ccUnderTrain
            module: 5
            spec: [{ teeth: 26, web: "rings" },
                   { teeth: 14, ang: 165, tooth: "block", web: "spokes", spokes: 4 },
                   { teeth: 18, ang: 20, on: 0, tooth: "fine", web: "spokes", spokes: 6, twist: -22 }]
            colors: [machinery.tints[0], machinery.tints[2], machinery.tints[1]]
            drive: -ccMachinery.drive * 1.2
            x: ccPanel.x + ccPanel.width - 90 - anchor0.x
            y: ccPanel.y + ccPanel.height + 6 - anchor0.y
        }
        BrassArc {
            readonly property point c: cc.wheelAt(ccSideTrain, 0)
            cx: c.x; cy: c.y; r: cc.tipOf(ccSideTrain, 0) + 10
            start: 105; sweep: 125
            twin: true
            color: ccMachinery.line
        }
        BrassArc {
            readonly property point c: cc.wheelAt(ccUnderTrain, 0)
            cx: c.x; cy: c.y; r: cc.tipOf(ccUnderTrain, 0) + 10
            start: 40; sweep: 105
            ends: "dot"
            color: ccMachinery.line
        }
        BrassPipe {
            anchors.fill: parent
            readonly property real endY: cc.wheelAt(ccSideTrain, 0).y - cc.tipOf(ccSideTrain, 0) - 26
            points: [[ccPanel.x, ccPanel.y + 64],
                     [ccPanel.x - 96, ccPanel.y + 64],
                     [ccPanel.x - 96, endY]]
            color: ccMachinery.line
        }
        BrassPipe {
            anchors.fill: parent
            readonly property real bx: ccPanel.x + 70
            readonly property real by: ccPanel.y + ccPanel.height
            points: [[bx, by], [bx, by + 60], [bx - 170, by + 60], [bx - 170, by + 104]]
            bore: 8
            color: ccMachinery.line
        }
    }

    // ---- right: control center drawer ----
    GlassPanel {
        id: ccPanel
        anchors.top: parent.top
        anchors.topMargin: cc._topMargin
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: 380
        // content + inner inset (12) + flick margins (28) + a little extra breathing
        // room at the bottom so the last slider's knob isn't clipped
        height: Math.min(inner.implicitHeight + 12 + 28 + 10, cc.height - cc._topMargin - 24)
        radius: Theme.radius + 6
        glow: 0.4
        // Windows can't transform, so the drawer itself does: it slides in from
        // past the right edge with a gentle overshoot, swinging in on a slight
        // 3D tilt hinged at the screen edge. Contents then cascade in (_stage).
        readonly property real e: Theme.easeOutBack(cc.ccReveal, 1.1)
        opacity: Math.min(1, cc.ccReveal * 2.5)
        visible: cc.ccReveal > 0.001
        transform: [
            Translate { x: (1 - ccPanel.e) * (ccPanel.width + 40) },
            Rotation { origin.x: ccPanel.width; origin.y: ccPanel.height / 2; axis { x: 0; y: 1; z: 0 }
                       angle: (1 - Theme.easeOutCubic(cc.ccReveal)) * -24 }
        ]

        // steampunk frame: screws, a cog at bottom-left that winds in with the
        // reveal, and a link plate riding the top edge (the music wing mirrors
        // this with its own mix, so the two drawers aren't twins)
        BrassFrame {
            visible: Theme.steampunk
            anchors.fill: parent
            anchors.margins: 6
            radius: ccPanel.radius - 6
            color: Theme.alpha(Theme.accent, 0.7)
            corners: ["screw", "cross", "screw", "cog"]
            plate: "top"
            spin: cc.ccReveal * 135
            build: cc.ccReveal
        }

        // Absorb clicks on the panel background so they don't fall through to the
        // outside-click catcher. Declared before the content so interactive
        // children (sliders, tiles) still receive their own clicks.
        MouseArea { anchors.fill: parent }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 14
            clip: true
            contentWidth: width
            // +12 so the inner Column's own top/bottom inset (see below) is
            // included in the scrollable range.
            contentHeight: inner.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: inner
                // Inset a few px from the Flickable's own clip edge — hint badges
                // (HintOverlay) sit 3px up/left of their target, so an item flush
                // against local (0,0) has its badge clipped no matter how big the
                // Flickable's *outer* margin is (clip happens at the Flickable's
                // own local origin, not the panel's edge).
                x: 6
                y: 6
                width: flick.width - 12
                spacing: 14

                // Right-clicking a tile reveals its inline list (output devices /
                // Wi-Fi networks / Bluetooth devices).
                property bool audioPickerOpen: false
                property bool wifiOpen: false
                property bool btOpen: false

                // ---- header ----
                Row {
                    width: parent.width
                    opacity: cc._stage(0)
                    transform: Translate { x: (1 - cc._stage(0)) * 36 }
                    Text {
                        text: "Control Center"
                        color: Theme.text
                        font.pixelSize: Theme.fontSize + 3
                        font.weight: Font.Bold
                        width: parent.width - 56
                    }
                    IconGlyph {
                        id: gearIcon
                        name: "gear"; size: 18
                        color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Ui.tuneOpen = !Ui.tuneOpen }
                    }
                    Item { width: 10; height: 1 }
                    IconGlyph {
                        id: closeIcon
                        name: "close"; size: 18
                        color: Theme.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Ui.ccOpen = false }
                    }
                }

                BrassDivider {
                    visible: Theme.steampunk
                    width: parent.width
                    build: cc._stage(0)
                    color: Theme.alpha(Theme.accent, 0.8)
                    ends: "screw"; centre: "cog"
                    spin: cc.ccReveal * -180
                }

                // ---- quick toggles ----
                Grid {
                    width: parent.width
                    opacity: cc._stage(1)
                    transform: Translate { x: (1 - cc._stage(1)) * 48 }
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10
                    readonly property real cellW: (width - columnSpacing) / 2

                    ToggleTile {
                        id: wifiTile
                        width: parent.cellW
                        fitting: "gears"
                        icon: Net.enabled ? "wifi" : "wifiOff"
                        label: "Wi-Fi"
                        sub: Net.enabled ? (Net.activeSsid !== "" ? Net.activeSsid : "On") : "Off"
                        active: Net.enabled
                        onClicked: Net.setEnabled(!Net.enabled)
                        onRightClicked: inner.wifiOpen = !inner.wifiOpen
                    }
                    ToggleTile {
                        id: btTile
                        width: parent.cellW
                        fitting: "rails"
                        icon: BT.powered ? "bluetooth" : "bluetoothOff"
                        label: "Bluetooth"
                        sub: BT.powered ? (BT.connectedCount > 0 ? BT.connectedCount + " connected" : "On") : "Off"
                        active: BT.powered
                        onClicked: BT.setPowered(!BT.powered)
                        onRightClicked: inner.btOpen = !inner.btOpen
                    }
                    ToggleTile {
                        id: audioTile
                        width: parent.cellW
                        fitting: "plate"
                        icon: Audio.muted ? "volumeMute" : "volume"
                        label: "Audio"
                        sub: Audio.deviceName
                        active: !Audio.muted && Audio.available
                        onClicked: Audio.toggleMute()
                        onRightClicked: inner.audioPickerOpen = !inner.audioPickerOpen
                    }
                    ToggleTile {
                        id: dndTile
                        width: parent.cellW
                        fitting: "screws"
                        icon: "bell"
                        label: "DND"
                        sub: Notifs.dnd ? "On" : "Off"
                        active: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }

                // ---- inline output picker (right-click the Audio tile) ----
                Item {
                    width: parent.width
                    clip: true
                    height: inner.audioPickerOpen ? picker.implicitHeight : 0
                    opacity: inner.audioPickerOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    AudioSection { id: picker; width: parent.width }
                }

                // ---- sliders ----
                Slider {
                    id: volSlider
                    width: parent.width
                    opacity: cc._stage(2)
                    transform: Translate { x: (1 - cc._stage(2)) * 56 }
                    label: "Volume"; suffix: "%"
                    from: 0; to: 200
                    value: Math.round(Audio.volume * 100)
                    onMoved: (v) => Audio.setVolume(v / 100)
                }
                Slider {
                    id: briSlider
                    width: parent.width
                    opacity: cc._stage(3)
                    transform: Translate { x: (1 - cc._stage(3)) * 64 }
                    label: "Brightness"; suffix: "%"
                    from: 0; to: 100
                    value: Math.round(Brightness.value * 100)
                    onMoved: (v) => Brightness.setValue(v / 100)
                }

                // ---- Wi-Fi networks (right-click the Wi-Fi tile) ----
                BrassDivider {
                    visible: inner.wifiOpen
                    width: parent.width
                    color: Theme.alpha(Theme.accent, 0.7)
                    ends: "dot"; centre: "plate"; rail: false
                }
                Item {
                    width: parent.width
                    clip: true
                    height: inner.wifiOpen ? wifiSec.implicitHeight : 0
                    opacity: inner.wifiOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    WifiSection { id: wifiSec; width: parent.width; kbReturnTarget: kbScope }
                }

                // ---- Bluetooth devices (right-click the Bluetooth tile) ----
                BrassDivider {
                    visible: inner.btOpen
                    width: parent.width
                    color: Theme.alpha(Theme.accent, 0.7)
                    ends: "knurl"; centre: "none"; ticks: true
                }
                Item {
                    width: parent.width
                    clip: true
                    height: inner.btOpen ? btSec.implicitHeight : 0
                    opacity: inner.btOpen ? 1 : 0
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    BluetoothSection { id: btSec; width: parent.width }
                }

                BrassDivider {
                    visible: Notifs.count > 0
                    width: parent.width
                    build: cc._stage(4)
                    color: Theme.alpha(Theme.accent, 0.7)
                    ends: "knurl"; centre: "plate"
                }
                NotificationList {
                    id: notifList
                    visible: Notifs.count > 0
                    width: parent.width
                    opacity: cc._stage(4)
                    transform: Translate { x: (1 - cc._stage(4)) * 72 }
                }
            }

            // Vimium-style hint mode: "f" drops a lettered badge on every clickable
            // entry from _kbList(); typing its letters activates it. Lives inside the
            // Flickable so badge positions share `inner`'s coordinate space and scroll/
            // clip with it automatically.
            HintOverlay {
                id: hintOverlay
                mapTo: flick.contentItem
                viewport: ({ y: flick.contentY, height: flick.height })
            }
        }
    }
}
