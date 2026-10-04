import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The floating bar pill: a centered, top-anchored glass panel with three
// states — idle (wave + clock), expanded on hover (now-playing + clock/date +
// battery pill), and OSD (the same pill morphed to show volume/brightness).
PanelWindow {
    id: bar
    property var modelData
    screen: modelData

    anchors.top: true
    margins.top: 6
    color: "transparent"
    // Expanded/OSD rise to Overlay so a temporary expand is *allowed to override*
    // anything — including true-fullscreen windows, which Hyprland renders above the
    // Top layer. (Top↔Overlay re-commit reliably at runtime; Bottom→Top does not.)
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: mode === "idle" ? WlrLayershell.Top : WlrLayershell.Overlay

    // The idle "main pill" is removed: nothing shows at rest. The pill appears only
    // when expanded (hold Left Alt → `bar expand`) or as a transient OSD.
    //
    // `yieldToApp` is the "Don't cover these apps" setting: when a listed app is the
    // active window on THIS bar's screen, the *expanded* pill is suppressed here too,
    // so a hold-to-expand (or a stray hover) can never drop a panel over it. The OSD
    // still shows — it's transient and only appears in direct response to a volume /
    // brightness keypress, so it isn't "covering" anything unasked.
    readonly property bool yieldToApp: !!screen && !!ActiveWindow.byMonitor
        && ActiveWindow.matches(screen.name, Settings.pillYieldApps)
    readonly property bool pillHidden: mode === "idle" || (mode === "expanded" && yieldToApp)

    // ---- state ----
    property bool hovered: false
    property string osd: ""                       // "" | "volume" | "brightness"
    readonly property string mode: osd !== "" ? "osd" : ((hovered || Ui.barExpanded) ? "expanded" : "idle")
    property bool ready: false                     // suppress OSD flash on startup

    // ---- motion ----
    // `bloom` is the expanded content's master progress: the clock drops in first,
    // then the clockwork and battery unfurl outward from it (see Theme.stagger).
    property real bloom: mode === "expanded" && !pillHidden ? 1 : 0
    Behavior on bloom { NumberAnimation { duration: bar.bloom < 0.5 ? Theme.animDrawer : Theme.animMed; easing.type: Easing.Linear } }
    function _bloom(i) { return Theme.stagger(bar.bloom, i, 0.18, 0.6) }
    // Charging "powers up" the clockwork: gears overdrive, wings beat faster and
    // lightning crackles between them. `power` eases in/out so it spins up/down.
    property real power: Battery.charging ? 1 : 0
    Behavior on power { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    // per-strike glow kick on the pill, decays fast
    property real zap: 0
    NumberAnimation { id: zapAnim; target: bar; property: "zap"; from: 1; to: 0; duration: 260; easing.type: Easing.OutCubic }

    // A brief glow flare whenever the pill wakes up (expand / OSD / notification).
    property real flare: 0
    NumberAnimation { id: flareAnim; target: bar; property: "flare"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }
    onModeChanged: if (mode !== "idle") flareAnim.restart()


    // ---- clock ----
    property string timeStr: ""
    property string dateStr: ""
    function _tick() {
        var d = new Date()
        timeStr = Qt.formatTime(d, "HH:mm")
        dateStr = Qt.formatDate(d, "ddd, MMM d")
    }
    Component.onCompleted: _tick()
    Timer { running: true; interval: 1000; repeat: true; onTriggered: bar._tick() }
    Timer { running: true; interval: 1500; onTriggered: bar.ready = true }

    // ---- OSD triggers ----
    function _showOsd(kind) {
        if (!bar.ready) return
        bar.osd = kind
        osdTimer.restart()
        osdPop.restart()
    }
    Timer { id: osdTimer; interval: 1600; onTriggered: bar.osd = "" }

    // Small delay before collapsing so brief exits (e.g. crossing the mask edge
    // mid-animation) don't flap the expanded state.
    Timer { id: collapseTimer; interval: 140; onTriggered: bar.hovered = false }
    Connections {
        target: Audio
        function onVolumeChanged() { bar._showOsd("volume") }
        function onMutedChanged() { bar._showOsd("volume") }
    }
    Connections {
        target: Brightness
        function onValueChanged() { bar._showOsd("brightness") }
    }

    // ---- notifications (pill below the bar) ----
    property real notifGap: 6
    property real notifWidth: 320
    property bool toastActive: false               // idle toast currently peeking
    readonly property var latestNotif: Notifs.count > 0 ? Notifs.list[Notifs.count - 1] : null
    // A fresh notification pops the idle toast; it retracts after a few seconds.
    Timer { id: toastTimer; interval: 3400; onTriggered: bar.toastActive = false }
    Connections {
        target: Notifs
        function onNotified(n) {
            if (Notifs.dnd) return
            bar.toastActive = true
            toastTimer.restart()
            flareAnim.restart()
        }
    }

    // ---- sizing ----
    // Each state gets its OWN content padding (idle vs expanded, tuned separately).
    // The WINDOW is sized to the max across states (NOT hover-driven) so the layer
    // surface never resizes under the cursor — resizing a layer-shell surface makes
    // Hyprland re-send pointer enter/leave, which collapses the pill on every mouse
    // move. Only the inner pill animates its width + height; input is masked to the
    // pill so the rest of the window stays click-through. The pill is top-anchored,
    // so the expanded state grows downward and only the resting height is reserved.
    readonly property real idleW: idleView.implicitWidth + Theme.idlePad * 2
    readonly property real expW: expandedView.implicitWidth + Theme.expPad * 2
    readonly property real osdW: osdView.implicitWidth + Theme.idlePad * 2
    readonly property real idleH: idleView.implicitHeight + Theme.idleVPad * 2
    readonly property real expH: expandedView.implicitHeight + Theme.expVPad * 2
    readonly property real osdH: osdView.implicitHeight + Theme.idleVPad * 2

    readonly property real targetWidth: mode === "osd" ? osdW : mode === "expanded" ? expW : idleW
    readonly property real targetHeight: mode === "osd" ? osdH : mode === "expanded" ? expH : idleH

    // The window also reserves a fixed strip BELOW the pill for the notification
    // surface (expanded list / idle toast) that hangs off the pill's bottom edge.
    // Reserving a constant amount (not content-driven) keeps the layer surface from
    // resizing when notifications arrive — which would re-send pointer enter/leave.
    readonly property real notifReserve: notifGap + 3 * (Theme.fontSize * 2 + 20) + 20
    // +48 leaves room for the springy width overshoot so it never clips.
    // + room for the clockwork wings that flank the expanded pill (they overlap
    // its edge by `wingTuck`).
    readonly property real wingTuck: 12
    implicitWidth: Math.max(idleW, expW + 2 * (wingL.width - wingTuck), osdW, notifWidth) + 48
    implicitHeight: Math.max(idleH, expH, osdH) + notifReserve
    exclusiveZone: 0            // float over the workspace instead of reserving a strip

    // Mask input to the pill plus whichever notification surface is visible. When
    // the pill is hidden (yielding to an app), the pill contributes nothing so the
    // masked-away region lets clicks fall through to the app underneath.
    readonly property real _maskW: {
        var w = bar.pillHidden ? 0 : panel.width
        if (toastPill.visible) w = Math.max(w, toastPill.width)
        if (expNotifPanel.visible) w = Math.max(w, expNotifPanel.width)
        return w
    }
    readonly property real _maskBottom: {
        var b = bar.pillHidden ? 0 : panel.height
        if (toastPill.visible) b = Math.max(b, toastPill.y + toastPill.height)
        if (expNotifPanel.visible) b = Math.max(b, expNotifPanel.y + expNotifPanel.height)
        return b
    }
    mask: Region {
        x: (bar.width - bar._maskW) / 2
        y: 0
        width: bar._maskW
        height: bar._maskBottom
    }

    // ---- clockwork wings (decorative, behind the pill, outside the input mask) ----
    // They unfold after the pill lands (bloom stage 2) and fold back first on close.
    MechWing {
        id: wingR
        x: panel.x + panel.width - bar.wingTuck
        y: panel.y + panel.height / 2 - hingeY
        spread: bar._bloom(2)
        power: bar.power
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: opacity > 0.01
    }
    MechWing {
        id: wingL
        x: panel.x - width + bar.wingTuck
        y: panel.y + panel.height / 2 - hingeY
        spread: bar._bloom(2)
        power: bar.power
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: opacity > 0.01
        transform: Scale { origin.x: wingL.width / 2; xScale: -1 }
    }

    GlassPanel {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: bar.targetWidth
        height: bar.targetHeight
        radius: height / 2
        glow: Math.min(1, (bar.hovered ? 0.6 : 0) + bar.flare * 0.9 + bar.power * (0.25 + 0.6 * bar.zap))
        // Hidden at rest / while yielding to a configured app. Appearing, the pill
        // "drops" out of the top edge: it pops from a squashed droplet to full size
        // with a springy overshoot; hiding, it shrinks back up quickly.
        opacity: bar.pillHidden ? 0 : 1
        visible: opacity > 0.01
        transformOrigin: Item.Top
        scale: bar.pillHidden ? 0.55 : 1
        Behavior on opacity { NumberAnimation { duration: bar.pillHidden ? Theme.animFast : Theme.animMed } }
        Behavior on scale {
            NumberAnimation { duration: bar.pillHidden ? Theme.animMed : Theme.animSlow
                              easing.type: bar.pillHidden ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.6 }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { collapseTimer.stop(); bar.hovered = true }
            onExited: collapseTimer.restart()
            onClicked: Ui.toggleCC()
            // Scroll over the pill to nudge volume (5% steps); OSD reflects it.
            onWheel: (wheel) => {
                var step = (wheel.angleDelta.y > 0 ? 1 : -1) * 0.05
                Audio.setVolume(Audio.volume + step)
            }
        }

        // ---------- idle ----------
        Row {
            id: idleView
            anchors.centerIn: parent
            spacing: 10
            opacity: bar.mode === "idle" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            AudioWave {
                anchors.verticalCenter: parent.verticalCenter
                active: Media.playing
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.timeStr
                color: Theme.text
                font.pixelSize: Theme.fontSize + 2
                font.weight: Font.Medium
            }
        }

        // ---------- expanded (hover) ----------
        Column {
            id: expandedView
            anchors.centerIn: parent
            spacing: 8
            opacity: bar.mode === "expanded" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

          // top row: clockwork + clock + battery pill + mirrored clockwork
          Row {
            id: expandedTop
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            // ---- clockwork (gear train: CPU-load spin + seconds escapement) ----
            ClockworkCluster {
                id: clockworkLeft
                anchors.verticalCenter: parent.verticalCenter
                power: bar.power
                wind: bar._bloom(1)
                running: bar.mode === "expanded" && !bar.pillHidden
                opacity: bar._bloom(1)
                transform: Translate { x: (1 - bar._bloom(1)) * -28 }
            }

            // ---- clock + date ----
            Column {
                anchors.verticalCenter: parent.verticalCenter
                opacity: bar._bloom(0)
                scale: 0.8 + 0.2 * bar._bloom(0)
                transform: Translate { y: (1 - bar._bloom(0)) * -10 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.timeStr
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 6
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.dateStr
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                }
            }

            // ---- battery pill ----
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Battery.present
                opacity: bar._bloom(1)
                transform: Translate { x: (1 - bar._bloom(1)) * 28 }

                Rectangle {
                    readonly property bool low: !Battery.charging && Battery.percent <= 20
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26; radius: 9
                    width: battRow.implicitWidth + 16
                    color: Battery.charging ? Theme.alpha(Theme.accent, 0.92)
                                             : (low ? Theme.alpha(Theme.danger, 0.18)
                                                    : Theme.alpha(Theme.current.hover, 0.5))
                    Row {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 5
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "battery"
                            battPercent: Battery.percent
                            battCharging: Battery.charging
                            color: Battery.charging ? Theme.current.onAccent
                                                     : (parent.parent.low ? Theme.danger : Theme.subtext)
                            size: 14
                        }
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Battery.charging
                            width: visible ? implicitWidth : 0
                            name: "bolt"
                            color: Theme.current.onAccent
                            size: 11
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.percent + "%"
                            color: Battery.charging ? Theme.current.onAccent
                                                     : (parent.parent.low ? Theme.danger : Theme.text)
                            font.pixelSize: Theme.fontSize - 3
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.openCC("") }
                }
            }

            // ---- mirrored clockwork (right-hand twin; a mirror image still meshes) ----
            ClockworkCluster {
                id: clockworkRight
                anchors.verticalCenter: parent.verticalCenter
                power: bar.power
                wind: bar._bloom(1)
                running: bar.mode === "expanded" && !bar.pillHidden
                opacity: bar._bloom(1)
                transform: [
                    Scale { origin.x: clockworkRight.width / 2; xScale: -1 },
                    Translate { x: (1 - bar._bloom(1)) * 28 }
                ]
            }
          }
        }
        // ---------- OSD ----------
        Row {
            id: osdView
            anchors.centerIn: parent
            spacing: 10
            opacity: bar.mode === "osd" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            readonly property real val: bar.osd === "brightness" ? Brightness.value
                                       : (Audio.muted ? 0 : Audio.volume)
            // Volume can reach 200%; brightness tops out at 100%. Scale the bar fill
            // to whichever max applies so a full bar reads correctly per kind.
            readonly property real maxVal: bar.osd === "brightness" ? 1 : 2

            IconGlyph {
                id: osdIcon
                anchors.verticalCenter: parent.verticalCenter
                name: bar.osd === "brightness" ? "brightness"
                     : (Audio.muted ? "volumeMute" : "volume")
                color: Theme.text
                size: 17
                // brightness glyph turns with the level; both "tick" on each step
                rotation: bar.osd === "brightness" ? osdView.val * 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }
            // per-keypress pop on the icon
            SequentialAnimation {
                id: osdPop
                NumberAnimation { target: osdIcon; property: "scale"; to: 1.3; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: osdIcon; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 }
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 130; height: 12
                readonly property real frac: Math.max(0, Math.min(1, osdView.val / osdView.maxVal))
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Theme.alpha(Theme.subtext, 0.3)
                }
                Rectangle {
                    id: osdFill
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6; radius: 3
                    width: Math.max(height, parent.width * parent.frac)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0.65) }
                        GradientStop { position: 1.0; color: Theme.accent }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                }
                // glowing knob riding the fill's leading edge
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: osdFill.width - width / 2
                    width: 12; height: 12; radius: 6
                    color: Theme.accent
                    border.width: 2
                    border.color: Theme.alpha("#ffffff", 0.85)
                    scale: osdIcon.scale
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osdView.val * 100) + "%"
                color: Theme.text
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
                width: Math.max(implicitWidth, 38)
            }
        }
    }

    // ---------- charging lightning (over the pill, gears and wings) ----------
    // Decorative only: outside the input mask, so it never eats clicks.
    LightningArcs {
        id: lightning
        x: wingL.x
        y: 0
        width: wingR.x + wingR.width - wingL.x
        height: panel.height + 30
        active: bar.power > 0.5 && bar.mode === "expanded" && !bar.pillHidden && bar.bloom > 0.9
        visible: active
        onStruck: zapAnim.restart()
        links: function () {
            var out = []
            function m(item, p) { return item.mapToItem(lightning, p.x, p.y) }
            function link(a, b) { out.push([a.x, a.y, b.x, b.y]) }
            function rnd(lo, hi) { return lo + Math.random() * (hi - lo) }
            var sides = [[clockworkLeft, wingL], [clockworkRight, wingR]]
            for (var i = 0; i < 2; i++) {
                var cw = sides[i][0], wg = sides[i][1]
                var hinge = m(wg, Qt.point(wg.hingeX, wg.hingeY))
                link(m(cw, cw.wheelCenter(0)), hinge)                       // gears → wing hinge
                link(m(cw, cw.wheelCenter(0)), m(cw, cw.wheelCenter(2)))    // across the train
                link(m(cw, cw.wheelCenter(1)), m(cw, cw.wheelCenter(3)))
                link(hinge, m(wg, wg.armPoint(1)))                          // along the arm
                link(m(wg, wg.armPoint(rnd(0.3, 1))), m(wg, wg.tipPoint(Math.floor(rnd(3, 11)))))  // out to a feather tip
                link(m(wg, wg.armPoint(rnd(0.5, 1))), m(wg, wg.tipPoint(Math.floor(rnd(6, 11)))))
            }
            return out
        }
    }

    // ---------- notification list (hangs below the expanded pill) ----------
    GlassPanel {
        id: expNotifPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: panel.bottom
        anchors.topMargin: bar.notifGap
        width: bar.notifWidth
        height: expNotifCol.implicitHeight + 16
        radius: Theme.radius
        glow: 0.4

        readonly property bool shown: bar.mode === "expanded" && Notifs.count > 0 && !bar.yieldToApp
        opacity: shown ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            y: expNotifPanel.shown ? 0 : -18
            Behavior on y { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        // Hover keep-alive: moving the cursor down from the pill into the list must
        // not trigger the collapse timer.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { collapseTimer.stop(); bar.hovered = true }
            onExited: collapseTimer.restart()
        }

        Column {
            id: expNotifCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 5

            Repeater {
                model: Math.min(3, Notifs.count)     // the 3 most recent
                delegate: Rectangle {
                    id: nCard
                    required property int index
                    readonly property var n: Notifs.list[Notifs.count - 1 - index]
                    width: expNotifCol.width
                    radius: Theme.radiusSm
                    color: Theme.alpha(Theme.current.hover, 0.5)
                    border.width: 1
                    border.color: Theme.strokeGlass
                    implicitHeight: nrow.implicitHeight + 12

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.activate(nCard.n)
                    }

                    Row {
                        id: nrow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 9; rightMargin: 9 }
                        spacing: 7
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "bell"; size: 13; color: Theme.subtext
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            spacing: 0
                            Text {
                                text: (nCard.n && nCard.n.summary) || "Notification"
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 3
                                font.weight: Font.DemiBold
                                width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                text: (nCard.n && nCard.n.body) || ""
                                visible: text !== ""
                                color: Theme.subtext
                                font.pixelSize: Theme.fontSize - 4
                                width: parent.width; elide: Text.ElideRight
                            }
                        }
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "close"; size: 12; color: Theme.subtext
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dismiss(nCard.n) }
                        }
                    }
                }
            }
        }
    }

    // ---------- idle toast: a small pill that peeks below the main pill on a new
    // notification, then slides UP and fades INTO the pill when it retracts ----------
    GlassPanel {
        id: toastPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: panel.bottom
        anchors.topMargin: bar.notifGap
        width: Math.min(bar.notifWidth, toastRow.implicitWidth + 22)
        height: toastRow.implicitHeight + 12
        radius: height / 2
        glow: 0.3

        readonly property bool shown: bar.mode === "idle" && bar.toastActive && bar.latestNotif !== null && !bar.yieldToApp
        opacity: shown ? 1 : 0
        visible: opacity > 0
        // When hidden, translate up by its full height + gap so it vanishes into
        // the main pill; when shown, it slides back down out of the pill.
        transform: Translate {
            y: toastPill.shown ? 0 : -(toastPill.height + bar.notifGap)
            Behavior on y { NumberAnimation { duration: toastPill.shown ? Theme.animSlow : Theme.animMed
                                              easing.type: toastPill.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.animMed } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: toastTimer.stop()          // linger while hovered
            onExited: toastTimer.restart()
            onClicked: Notifs.activate(bar.latestNotif)
        }

        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            IconGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "bell"; size: 13; color: Theme.accent
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: (bar.latestNotif && bar.latestNotif.summary) || "Notification"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize - 2
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, bar.notifWidth - 60)
                }
                // Body/content, gated by the "show content" setting.
                Text {
                    text: (bar.latestNotif && bar.latestNotif.body) || ""
                    visible: Settings.notifToastContent && text !== ""
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 4
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, bar.notifWidth - 60)
                }
            }
        }
    }
}
