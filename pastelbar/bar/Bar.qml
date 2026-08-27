import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// The floating bar pill: a centered, top-anchored glass panel with three
// states — idle (wave + clock), expanded on hover (now-playing + clock/date +
// wifi/bt pills), and OSD (the same pill morphed to show volume/brightness).
PanelWindow {
    id: bar
    property var modelData
    screen: modelData

    anchors.top: true
    margins.top: 6
    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Top

    // ---- state ----
    property bool hovered: false
    property string osd: ""                       // "" | "volume" | "brightness"
    readonly property string mode: osd !== "" ? "osd" : (hovered ? "expanded" : "idle")
    property bool ready: false                     // suppress OSD flash on startup

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
    function _showOsd(kind) { if (!bar.ready) return; bar.osd = kind; osdTimer.restart() }
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
    implicitWidth: Math.max(idleW, expW, osdW, notifWidth)
    implicitHeight: Math.max(idleH, expH, osdH) + notifReserve
    exclusiveZone: 0            // float over the workspace instead of reserving a strip

    // Mask input to the pill plus whichever notification surface is visible.
    readonly property real _maskW: {
        var w = panel.width
        if (toastPill.visible) w = Math.max(w, toastPill.width)
        if (expNotifPanel.visible) w = Math.max(w, expNotifPanel.width)
        return w
    }
    readonly property real _maskBottom: {
        var b = panel.height
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

    GlassPanel {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: bar.targetWidth
        height: bar.targetHeight
        radius: height / 2
        glow: bar.hovered ? 0.6 : 0
        Behavior on width {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
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

          // top row: now-playing + clock + wifi/bt pills
          Row {
            id: expandedTop
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22

            // ---- now-playing (circular art + wave + title/artist) ----
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                // circular album art (masked to a circle)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.alpha(Theme.subtext, 0.25)
                        visible: Media.artUrl === ""
                        IconGlyph { anchors.centerIn: parent; name: "volume"; size: 15; color: Theme.subtext }
                    }
                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: artImg
                        maskEnabled: true
                        maskSource: artMask
                        visible: Media.artUrl !== ""
                    }
                    Item {
                        id: artMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: width / 2 }
                    }
                }

                AudioWave {
                    anchors.verticalCenter: parent.verticalCenter
                    active: Media.playing
                    implicitWidth: 18
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: Media.title || "Nothing playing"
                        color: Theme.text
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 150)
                    }
                    Text {
                        text: Media.artist
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 3
                        visible: Media.artist !== ""
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 150)
                    }
                }
            }

            // ---- clock + date ----
            Column {
                anchors.verticalCenter: parent.verticalCenter
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

            // ---- wifi + bt/battery pills ----
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // wifi
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 26; radius: 9
                    color: Net.enabled ? Theme.alpha(Theme.accent, 0.92)
                                       : Theme.alpha(Theme.current.hover, 0.5)
                    IconGlyph {
                        anchors.centerIn: parent
                        name: Net.enabled ? "wifi" : "wifiOff"
                        color: Net.enabled ? Theme.current.onAccent : Theme.subtext
                        size: 16
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.openCC("wifi") }
                }

                // bluetooth / battery
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26; radius: 9
                    width: btRow.implicitWidth + 16
                    color: BT.powered ? Theme.alpha(Theme.accent, 0.92)
                                      : Theme.alpha(Theme.current.hover, 0.5)
                    Row {
                        id: btRow
                        anchors.centerIn: parent
                        spacing: 5
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: BT.powered ? "bluetooth" : "bluetoothOff"
                            color: BT.powered ? Theme.current.onAccent : Theme.subtext
                            size: 14
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: BT.battery >= 0
                            text: BT.battery.toString()
                            color: Theme.current.onAccent
                            font.pixelSize: Theme.fontSize - 3
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.openCC("bt") }
                }
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
                anchors.verticalCenter: parent.verticalCenter
                name: bar.osd === "brightness" ? "brightness"
                     : (Audio.muted ? "volumeMute" : "volume")
                color: Theme.text
                size: 17
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 130; height: 6; radius: 3
                color: Theme.alpha(Theme.subtext, 0.3)
                Rectangle {
                    height: parent.height; radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, osdView.val / osdView.maxVal))
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.animFast } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(osdView.val * 100) + "%"
                color: Theme.text
                font.pixelSize: Theme.fontSize - 1
                font.weight: Font.Medium
            }
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

        readonly property bool shown: bar.mode === "expanded" && Notifs.count > 0
        opacity: shown ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            y: expNotifPanel.shown ? 0 : -10
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
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

        readonly property bool shown: bar.mode === "idle" && bar.toastActive && bar.latestNotif !== null
        opacity: shown ? 1 : 0
        visible: opacity > 0
        // When hidden, translate up by its full height + gap so it vanishes into
        // the main pill; when shown, it slides back down out of the pill.
        transform: Translate {
            y: toastPill.shown ? 0 : -(toastPill.height + bar.notifGap)
            Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.InOutCubic } }
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
