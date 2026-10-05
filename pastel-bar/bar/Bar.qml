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
    // While a collapse winds down, keep drawing the expanded pill so its brass
    // dressing (PillFrame) and content can unbuild off `bloom` in reverse; only
    // hide it once everything is packed away. Input is still dropped at once
    // (the mask follows pillHidden), so a closing pill never eats clicks.
    readonly property bool winding: mode === "idle" && bloom > 0.02
    // same for the OSD in steampunk mode: its pill dressing unbuilds off osdReveal
    property real osdReveal: mode === "osd" ? 1 : 0
    Behavior on osdReveal { NumberAnimation { duration: Theme.decorated ? (bar.mode === "osd" ? 620 : 380) : Theme.animFast
                                              easing.type: Easing.Linear } }
    readonly property bool osdWinding: Theme.decorated && mode === "idle" && !winding && osdReveal > 0.02
    readonly property bool shownHidden: pillHidden && !winding && !osdWinding
    readonly property bool expLayout: mode === "expanded" || winding

    // ---- state ----
    property bool hovered: false
    property string osd: ""                       // "" | "volume" | "brightness"
    readonly property string mode: osd !== "" ? "osd" : ((hovered || Ui.barExpanded) ? "expanded" : "idle")
    property bool ready: false                     // suppress OSD flash on startup

    // ---- motion ----
    // `bloom` is the expanded content's master progress: the clock drops in first,
    // then the clockwork and battery unfurl outward from it (see Theme.stagger).
    property real bloom: mode === "expanded" && !pillHidden ? 1 : 0
    // Opening is a long, staged build (PillFrame's rails → caps → screws → steam);
    // closing replays it backwards, quicker.
    Behavior on bloom { NumberAnimation { duration: Theme.steampunk ? (bar.bloom < 0.5 ? 1000 : 560)
                                                : Theme.cyberpunk ? (bar.bloom < 0.5 ? 850 : 480)
                                                : (bar.bloom < 0.5 ? Theme.animDrawer : Theme.animMed)
                                          easing.type: Easing.Linear } }
    function _bloom(i) { return Theme.stagger(bar.bloom, i, 0.18, 0.6) }
    function _seg(a, b) { return Math.max(0, Math.min(1, (bar.bloom - a) / (b - a))) }
    // Charging "powers up" the clockwork: gears overdrive, wings beat faster and
    // lightning crackles between them. `power` eases in/out so it spins up/down.
    property real power: Battery.charging ? 1 : 0
    Behavior on power { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    // Low battery (≤20%, not charging) wears it down: wings droop, gears strain.
    // Deepens as the charge drains toward empty.
    property real weak: Battery.present && !Battery.charging && Battery.percent <= 20
                        ? 0.6 + 0.4 * Math.max(0, 20 - Battery.percent) / 20 : 0
    Behavior on weak { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
    // per-strike glow kick on the pill, decays fast
    property real zap: 0
    NumberAnimation { id: zapAnim; target: bar; property: "zap"; from: 1; to: 0; duration: 260; easing.type: Easing.OutCubic }

    // A brief glow flare whenever the pill wakes up (expand / OSD / notification).
    property real flare: 0
    NumberAnimation { id: flareAnim; target: bar; property: "flare"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }
    onModeChanged: if (mode !== "idle") flareAnim.restart()


    // ---- cyberpunk idle clock: 0..1 every 3.2 s, drives the scanline + post lights ----
    readonly property bool cyberLive: Theme.cyberpunk && !bar.shownHidden
    property real cyPhase: 0
    FrameAnimation {
        running: bar.cyberLive && bar.visible
        onTriggered: bar.cyPhase = (bar.cyPhase + frameTime / 3.2) % 1
    }

    // ---- clock ----
    property string timeStr: ""
    property string dateStr: ""
    property int secs: 0
    function _tick() {
        var d = new Date()
        secs = d.getSeconds()
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

    readonly property real targetWidth: mode === "osd" || osdWinding ? osdW : expLayout ? expW : idleW
    readonly property real targetHeight: mode === "osd" || osdWinding ? osdH : expLayout ? expH : idleH

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
        droop: bar.weak
        tilt: 14      // the pill hugs the top edge — swing the wings down so the flap never clips it
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: Theme.steampunk && opacity > 0.01
    }
    MechWing {
        id: wingL
        x: panel.x - width + bar.wingTuck
        y: panel.y + panel.height / 2 - hingeY
        spread: bar._bloom(2)
        power: bar.power
        droop: bar.weak
        tilt: 14      // the pill hugs the top edge — swing the wings down so the flap never clips it
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: Theme.steampunk && opacity > 0.01
        transform: Scale { origin.x: wingL.width / 2; xScale: -1 }
    }

    // ---- cyberpunk fins (the wings' counterpart; same slot, same timing) ----
    CyberFin {
        id: finR
        x: panel.x + panel.width - 10
        y: panel.y + panel.height / 2 - height / 2 + 4
        spread: bar._bloom(2)
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: Theme.cyberpunk && opacity > 0.01
    }
    CyberFin {
        id: finL
        x: panel.x - width + 10
        y: panel.y + panel.height / 2 - height / 2 + 4
        spread: bar._bloom(2)
        running: bar.mode === "expanded" && !bar.pillHidden
        opacity: Math.min(1, spread * 3)
        visible: Theme.cyberpunk && opacity > 0.01
        transform: Scale { origin.x: finL.width / 2; xScale: -1 }
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
        // (while winding down it fades with the last of the bloom)
        opacity: bar.shownHidden ? 0 : (bar.winding ? Math.min(1, bar.bloom * 6)
                                      : bar.osdWinding ? Math.min(1, bar.osdReveal * 6) : 1)
        visible: opacity > 0.01
        transformOrigin: Item.Top
        scale: bar.shownHidden ? 0.55 : (bar.winding ? 0.8 + 0.2 * Math.min(1, bar.bloom * 4) : 1)
        Behavior on opacity { NumberAnimation { duration: bar.shownHidden ? Theme.animFast : Theme.animMed } }
        Behavior on scale {
            NumberAnimation { duration: bar.shownHidden ? Theme.animMed : Theme.animSlow
                              easing.type: bar.shownHidden ? Easing.InCubic : Easing.OutBack; easing.overshoot: 1.6 }
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

        // ---------- steampunk dressing (builds / unbuilds off bloom) ----------
        PillFrame {
            anchors.fill: parent
            visible: (bar.expLayout || bar.mode === "osd" || bar.osdWinding) && Theme.steampunk
            t: bar.expLayout ? bar.bloom : bar.osdReveal
            pulse: bar.mode === "expanded" ? 1 - clockworkLeft.tickP : 0
        }

        // ---------- cyberpunk dressing (builds / unbuilds off bloom / osdReveal) ----------
        CyberFrame {
            anchors.fill: parent
            anchors.margins: 4
            cut: panel.cut - 1.7
            color: Theme.alpha(Theme.accent, 0.8)
            corners: ["none", "none", "wedge", "wedge"]
            tab: bar.expLayout ? "bottom" : "none"
            rail: false
            lap: 4.5
            build: bar.expLayout ? bar.bloom
                 : (bar.mode === "osd" || bar.osdWinding) ? bar.osdReveal : 0
        }
        // scanline: a soft bright band sweeping left → right, kept clear of the
        // chamfered ends so it never paints outside the glass
        Item {
            visible: bar.cyberLive && (bar.expLayout ? bar.bloom > 0.99 : bar.mode === "osd")
            x: panel.cut; y: 3
            width: panel.width - 2 * panel.cut; height: panel.height - 6
            clip: true
            Rectangle {
                width: 46; height: parent.height
                x: -width + (parent.width + width) * bar.cyPhase
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.85; color: Theme.alpha(Theme.accent, 0.13) }
                    GradientStop { position: 1.0; color: Theme.alpha(Qt.lighter(Theme.accent, 1.4), 0.45) }
                }
            }
        }

        // ---------- idle ----------
        Row {
            id: idleView
            anchors.centerIn: parent
            spacing: 10
            // the idle pill is retired (pill hidden at rest); never let its clock
            // ghost through while the expanded pill winds down
            opacity: bar.mode === "idle" && !bar.pillHidden ? 1 : 0
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
            opacity: bar.expLayout ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

          // brass posts between the clockwork and the clock: a rail that extends
          // from its middle, then a ring at each end
          component BrassPost: Item {
              property real p: 0
              visible: Theme.steampunk
              anchors.verticalCenter: parent.verticalCenter
              width: 8; height: 34
              readonly property real len: (height - 8) * Theme.easeOutCubic(p)
              Rectangle {
                  x: (parent.width - width) / 2; y: (parent.height - height) / 2
                  width: 1.6; height: parent.len
                  color: Theme.alpha(Theme.accent, 0.8)
              }
              Repeater {
                  model: 2
                  Rectangle {
                      required property int index
                      width: 6; height: 6; radius: 3
                      x: 1
                      y: parent.height / 2 + (index ? 1 : -1) * parent.len / 2 - 3
                      scale: Theme.easeOutBack(Math.max(0, parent.p * 2 - 1), 2.5)
                      color: "transparent"
                      border.width: 1.4; border.color: Theme.alpha(Theme.accent, 0.85)
                  }
              }
          }

          // cyberpunk posts: a hairline rail that extends from its middle with
          // three node lights on it that blink in turn
          component CyberPost: Item {
              id: cpost
              property real p: 0
              property real phase: 0
              visible: Theme.cyberpunk
              anchors.verticalCenter: parent.verticalCenter
              width: 6; height: 34
              readonly property real len: (height - 4) * Theme.easeOutCubic(p)
              Rectangle {
                  x: 2.5; y: (parent.height - height) / 2
                  width: 1; height: cpost.len
                  color: Theme.alpha(Theme.accent, 0.7)
              }
              Repeater {
                  model: 3
                  Rectangle {
                      required property int index
                      x: 1; width: 4; height: 4
                      y: cpost.height / 2 + (index - 1) * cpost.len / 2.6 - 2
                      color: Theme.accent
                      opacity: cpost.p < 0.6 ? 0
                             : (Math.floor(cpost.phase * 6) % 3 === index ? 1 : 0.3)
                  }
              }
          }

          // top row: clockwork + clock + battery pill + mirrored clockwork
          Row {
            id: expandedTop
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            // ---- clockwork (gear train: CPU-load spin + seconds escapement) ----
            ClockworkCluster {
                id: clockworkLeft
                visible: Theme.steampunk
                anchors.verticalCenter: parent.verticalCenter
                power: bar.power
                strain: bar.weak
                wind: bar._bloom(1)
                running: bar.mode === "expanded" && !bar.pillHidden
                opacity: bar._bloom(1)
                transform: Translate { x: (1 - bar._bloom(1)) * -28 }
            }
            BrassPost { p: bar._seg(0.22, 0.55) }

            // ---- cyberpunk: CPU gauge + readout ----
            Row {
                visible: Theme.cyberpunk
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: Math.min(1, bar._bloom(1) * 2)
                transform: Translate { x: (1 - bar._bloom(1)) * -28 }
                HudRing {
                    anchors.verticalCenter: parent.verticalCenter
                    value: SysLoad.cpu
                    build: bar._bloom(1)
                    running: bar.mode === "expanded" && !bar.pillHidden
                }
                CyberReadout {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "CPU"
                    value: SysLoad.cpu
                    history: SysLoad.cpuHist
                    build: bar._bloom(1)
                    running: bar.mode === "expanded" && !bar.pillHidden
                }
            }
            CyberPost { p: bar._seg(0.22, 0.55); phase: bar.cyPhase }

            // ---- clock + date ----
            Column {
                anchors.verticalCenter: parent.verticalCenter
                opacity: bar._bloom(0)
                scale: 0.8 + 0.2 * bar._bloom(0)
                transform: Translate { y: (1 - bar._bloom(0)) * -10 }
                // (cyberpunk: glitches every few seconds while the pill is open)
                GlitchText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bar.timeStr
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 6
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.cyberpunk ? 1.5 : 0
                    running: bar.mode === "expanded" && !bar.pillHidden && bar.bloom > 0.99
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.cyberpunk ? bar.dateStr.toUpperCase() : bar.dateStr
                    color: Theme.decorated ? Theme.alpha(Qt.lighter(Theme.accent, 1.15), 0.9) : Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                    font.letterSpacing: Theme.cyberpunk ? 1.5 : 0
                }
                // cyberpunk: a seconds ruler — 30 ticks, one per 2 s, the
                // current one blinking
                Row {
                    visible: Theme.cyberpunk
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 3
                    spacing: 1
                    Repeater {
                        model: 30
                        Rectangle {
                            required property int index
                            readonly property int cur: Math.floor(bar.secs / 2)
                            width: 2
                            height: index % 5 === 0 ? 4 : 2.5
                            anchors.bottom: parent.bottom
                            color: Theme.accent
                            opacity: index < cur ? 0.85
                                   : index === cur ? (bar.secs % 2 ? 1 : 0.3)
                                   : 0.2
                        }
                    }
                }
            }

            // ---- battery pill ----
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Battery.present
                opacity: bar._bloom(1)
                transform: Translate { x: (1 - bar._bloom(1)) * 28 }

                CyberRect {
                    readonly property bool low: !Battery.charging && Battery.percent <= 20
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26; radius: 13
                    width: battRow.implicitWidth + 16
                    color: low ? Theme.alpha(Theme.danger, 0.18)
                               : Theme.steampunk ? Theme.alpha("#000000", 0.2) : Theme.alpha(Theme.current.hover, 0.5)
                    border.width: Theme.steampunk || low ? 1.4 : 0
                    border.color: low ? Theme.alpha(Theme.danger, 0.8) : Theme.alpha(Theme.accent, 0.75)
                    Row {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 5
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "battery"
                            battPercent: Battery.percent
                            color: parent.parent.low ? Theme.danger : Theme.subtext
                            size: 14
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.percent + "%"
                            color: parent.parent.low ? Theme.danger : Theme.text
                            font.pixelSize: Theme.fontSize - 3
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.openCC("") }
                }
            }

            BrassPost { p: bar._seg(0.28, 0.61) }
            CyberPost { p: bar._seg(0.28, 0.61); phase: (bar.cyPhase + 0.5) % 1 }

            // ---- cyberpunk: memory readout + gauge ----
            Row {
                visible: Theme.cyberpunk
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                opacity: Math.min(1, bar._bloom(1) * 2)
                transform: Translate { x: (1 - bar._bloom(1)) * 28 }
                CyberReadout {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "MEM"
                    value: SysLoad.mem
                    history: SysLoad.memHist
                    alignRight: true
                    build: bar._bloom(1)
                    running: bar.mode === "expanded" && !bar.pillHidden
                }
                HudRing {
                    anchors.verticalCenter: parent.verticalCenter
                    value: SysLoad.mem
                    segments: 3
                    speed: -16
                    build: bar._bloom(1)
                    running: bar.mode === "expanded" && !bar.pillHidden
                }
            }

            // ---- mirrored clockwork (right-hand twin; a mirror image still meshes) ----
            ClockworkCluster {
                id: clockworkRight
                visible: Theme.steampunk
                anchors.verticalCenter: parent.verticalCenter
                power: bar.power
                strain: bar.weak
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
            opacity: bar.mode === "osd" || bar.osdWinding ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

            readonly property real val: bar.osd === "brightness" ? Brightness.value
                                       : (Audio.muted ? 0 : Audio.volume)
            // Volume can reach 200%; brightness tops out at 100%. Scale the bar fill
            // to whichever max applies so a full bar reads correctly per kind.
            readonly property real maxVal: bar.osd === "brightness" ? 1 : 2

            // steampunk: the icon sits in a brass porthole that pops in
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.decorated ? 28 : osdIcon.width; height: Theme.decorated ? 28 : osdIcon.height
                Chamfer {    // cyberpunk: a chamfered box that glitches in
                    visible: Theme.cyberpunk
                    anchors.fill: parent
                    cut: 7
                    cuts: [true, false, true, false]
                    color: Theme.alpha("#000000", 0.3)
                    strokeWidth: 1.5
                    strokeColor: Theme.alpha(Theme.accent, 0.85)
                    opacity: Math.floor(bar.osdReveal * 8) % 3 === 1 && bar.osdReveal < 1 ? 0.2 : 1
                }
                Rectangle {
                    visible: Theme.steampunk
                    anchors.fill: parent; radius: width / 2
                    color: Theme.alpha("#000000", 0.3)
                    border.width: 1.5; border.color: Theme.alpha(Theme.accent, 0.85)
                    scale: Theme.easeOutBack(Math.min(1, bar.osdReveal * 2), 2)
                }
            IconGlyph {
                id: osdIcon
                anchors.centerIn: parent
                name: bar.osd === "brightness" ? "brightness"
                     : (Audio.muted ? "volumeMute" : "volume")
                color: Theme.text
                size: 17
                // brightness glyph turns with the level; both "tick" on each step
                rotation: bar.osd === "brightness" ? osdView.val * 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }
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
                // cyberpunk: a segmented meter — cells light up to the level, the
                // leading one brightest; cells switch on left → right as it opens
                Row {
                    id: osdCells
                    visible: Theme.cyberpunk
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1.5
                    readonly property int lit: Math.round(parent.frac * 20)
                    Repeater {
                        model: 20
                        Rectangle {
                            required property int index
                            width: 5; height: 9
                            color: index < osdCells.lit ? (index === osdCells.lit - 1 ? Qt.lighter(Theme.accent, 1.35) : Theme.accent)
                                                        : Theme.alpha(Theme.accent, 0.18)
                            opacity: bar.osdReveal * 22 > index ? 1 : 0
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                    }
                }
                Rectangle {
                    visible: !Theme.cyberpunk
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Theme.steampunk ? Theme.alpha("#000000", 0.3) : Theme.alpha(Theme.subtext, 0.3)
                    border.width: Theme.steampunk ? 1 : 0
                    border.color: Theme.alpha(Theme.accent, 0.55)
                }
                // steampunk: gauge ticks that light up as the fill passes them
                Repeater {
                    model: Theme.steampunk ? 11 : 0
                    Rectangle {
                        required property int index
                        x: (parent.width - 1) * index / 10
                        y: parent.height / 2 + 5
                        width: 1; height: (index % 5 === 0 ? 4 : 2.5) * Theme.easeOutBack(Math.max(0, Math.min(1, bar.osdReveal * 2.2 - index * 0.08)), 2)
                        color: Theme.alpha(Theme.accent, index / 10 <= parent.frac ? 0.9 : 0.35)
                    }
                }
                Rectangle {
                    id: osdFill
                    visible: !Theme.cyberpunk
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
                // steampunk: a cog knob that turns with the level
                Gear {
                    visible: Theme.steampunk
                    anchors.verticalCenter: parent.verticalCenter
                    x: osdFill.width - width / 2
                    teeth: 12; module: 1.25
                    tooth: "block"; web: "solid"; engrave: true
                    color: Theme.accent
                    rim: Theme.alpha("#000000", 0.4)
                    pin: Qt.darker(Theme.accent, 2.4)
                    rotation: osdFill.width * 3
                    scale: osdIcon.scale * Theme.easeOutBack(Math.min(1, bar.osdReveal * 1.8), 2)
                }
                // glowing knob riding the fill's leading edge
                Rectangle {
                    visible: !Theme.decorated
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
                color: Theme.decorated ? Qt.lighter(Theme.accent, 1.2) : Theme.text
                font.family: Theme.decorated ? "monospace" : font.family
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
        active: Theme.steampunk && bar.power > 0.5 && bar.mode === "expanded" && !bar.pillHidden && bar.bloom > 0.9
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

        BrassFrame {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.radius - 4
            color: Theme.alpha(Theme.accent, 0.7)
            corners: ["screw", "screw", "screw", "screw"]
            rail: false
            build: expNotifPanel.shown ? Math.max(0, bar.bloom * 1.6 - 0.6) : 0
        }
        CyberFrame {
            anchors.fill: parent
            anchors.margins: 4
            cut: expNotifPanel.cut - 1.7
            color: Theme.alpha(Theme.accent, 0.7)
            corners: ["wedge", "none", "bracket", "none"]
            bar: "top"
            rail: false
            build: expNotifPanel.shown ? Math.max(0, bar.bloom * 1.6 - 0.6) : 0
        }

        Column {
            id: expNotifCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 5

            Repeater {
                model: Math.min(3, Notifs.count)     // the 3 most recent
                delegate: CyberRect {
                    id: nCard
                    required property int index
                    readonly property var n: Notifs.list[Notifs.count - 1 - index]
                    width: expNotifCol.width
                    radius: Theme.radiusSm
                    color: Theme.steampunk ? Theme.alpha("#000000", 0.2) : Theme.alpha(Theme.current.hover, 0.5)
                    border.width: Theme.steampunk ? 1.2 : 1
                    border.color: Theme.steampunk ? Theme.alpha(Theme.accent, 0.4) : Theme.strokeGlass
                    implicitHeight: nrow.implicitHeight + 12
                    // steampunk: cards drop in one after another as the list opens
                    readonly property real dropP: Theme.steampunk
                        ? Theme.easeOutBack(Math.max(0, Math.min(1, bar.bloom * 2.2 - 1 - index * 0.18)), 1.6) : 1
                    opacity: Math.min(1, dropP * 1.5)
                    transform: Translate { y: (1 - nCard.dropP) * -14 }

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
        // steampunk: a brass outline that draws as it drops out of the pill
        border.width: Theme.steampunk ? 1.5 : 1
        border.color: Theme.steampunk ? Theme.alpha(Theme.accent, 0.8 * toastPill.drawP) : Theme.strokeGlass
        property real drawP: shown ? 1 : 0
        Behavior on drawP { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        PillFrame {
            anchors.fill: parent
            visible: Theme.steampunk
            inset: 3
            line: 1.2
            showPlate: false
            t: toastPill.drawP
        }
        CyberFrame {
            anchors.fill: parent
            anchors.margins: 3
            cut: toastPill.cut - 1.3
            color: Theme.alpha(Theme.accent, 0.8)
            corners: ["none", "none", "wedge", "none"]
            rail: false
            lap: 3
            build: toastPill.drawP
        }

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
