import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

// Polkit "Authentication Required" dialog. Shows while an auth flow is active;
// binds to the Polkit service (services/Polkit -> PolkitAgent). Submits the typed
// response to the agent; shows supplementary errors on failure.
PanelWindow {
    id: win
    // Open on the focused monitor. Only re-targeted while hidden — moving a mapped
    // layer surface would re-create it mid-animation.
    property var _screen: null
    screen: _screen
    Component.onCompleted: _screen = Ui.focusedScreen
    Connections {
        target: Ui
        function onFocusedScreenChanged() { if (!win.visible) win._screen = Ui.focusedScreen }
    }
    // Keep mapped through the close animation, then unmap.
    readonly property bool open: Polkit.active
    visible: open || pkPanel.opacity > 0.01
    // steampunk: master open progress — the frame assembles, the backdrop
    // clockwork winds in, and closing runs it backwards before the panel fades
    property real spReveal: open ? 1 : 0
    Behavior on spReveal { NumberAnimation { duration: win.open ? 820 : 420; easing.type: Easing.Linear } }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    // Layer namespace — Hyprland's `pastel-bar` layer rule blurs whatever is behind
    // our glass (see hyprland.lua; ignore_alpha keeps fully-clear areas unblurred).
    WlrLayershell.namespace: "pastel-bar"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var flow: Polkit.flow

    onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }
    Connections {
        target: Polkit
        function onFlowChanged() { pw.text = "" }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.45)
        opacity: Theme.decorated ? win.spReveal : (win.open ? 1 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    PanelMachinery {
        anchors.fill: parent
        rx: pkPanel.x; ry: pkPanel.y; rw: pkPanel.width; rh: pkPanel.height
        reveal: win.spReveal
        variant: 3
    }
    PanelHud {    // cyberpunk counterpart
        anchors.fill: parent
        rx: pkPanel.x; ry: pkPanel.y; rw: pkPanel.width; rh: pkPanel.height
        reveal: win.spReveal
        variant: 3
    }

    GlassPanel {
        id: pkPanel
        cuts: [true, false, true, false]
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 36
        radius: Theme.radius
        glow: 0.6
        // quick scale + fade in/out from the centre
        scale: Theme.decorated ? 0.9 + 0.1 * Theme.easeOutBack(Math.min(1, win.spReveal * 1.6), 1.5)
                               : (win.open ? 1 : 0.88)
        opacity: Theme.decorated ? Math.min(1, win.spReveal * 3) : (win.open ? 1 : 0)
        // springy pop on open, quick tuck on close
        Behavior on scale { enabled: !Theme.decorated; NumberAnimation { duration: win.open ? Theme.animSlow : Theme.animMed
                                                easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { enabled: !Theme.decorated; NumberAnimation { duration: Theme.animFast } }
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 12

            Row {
                width: parent.width
                spacing: 10
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 20; color: Theme.accent }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Authentication Required"
                    color: Theme.text
                    font.pixelSize: Theme.fontSize + 2
                    font.weight: Font.Bold
                }
            }

            Text {
                width: parent.width
                text: win.flow ? win.flow.message : ""
                color: Theme.subtext
                font.pixelSize: Theme.fontSize - 1
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: win.flow && win.flow.actionId !== ""
                text: win.flow ? win.flow.actionId : ""
                color: Theme.alpha(Theme.subtext, 0.7)
                font.pixelSize: Theme.fontSize - 4
                elide: Text.ElideRight
            }

            // password / response field
            CyberRect {
                width: parent.width
                height: 38
                radius: Theme.radiusSm
                color: Theme.alpha(Theme.current.surface, 0.6)
                border.width: 1
                border.color: pw.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass

                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.pixelSize: Theme.fontSize
                    clip: true
                    echoMode: (win.flow && win.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                    enabled: win.flow && win.flow.isResponseRequired
                    onAccepted: Polkit.submit(text)
                    Keys.onEscapePressed: Polkit.cancel()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (win.flow && win.flow.inputPrompt) ? win.flow.inputPrompt : "Password"
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize
                        visible: pw.text === ""
                    }
                }
            }

            Text {
                width: parent.width
                visible: win.flow && win.flow.supplementaryMessage !== ""
                text: win.flow ? win.flow.supplementaryMessage : ""
                color: (win.flow && win.flow.supplementaryIsError) ? Theme.danger : Theme.subtext
                font.pixelSize: Theme.fontSize - 3
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                CyberRect {
                    width: 92; height: 34; radius: Theme.steampunk ? 17 : 9
                    color: Theme.steampunk ? Theme.alpha("#000000", cancelMa.containsMouse ? 0.12 : 0.22)
                         : (cancelMa.containsMouse ? Theme.alpha(Theme.current.hover, 0.8) : Theme.alpha(Theme.current.hover, 0.5))
                    border.width: Theme.steampunk ? 1.4 : 1
                    border.color: Theme.steampunk ? Theme.alpha(Theme.accent, cancelMa.containsMouse ? 0.8 : 0.45) : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.pixelSize: Theme.fontSize - 2 }
                    MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Polkit.cancel() }
                }
                CyberRect {
                    id: okBtn
                    width: 118; height: 34; radius: Theme.steampunk ? 17 : 9
                    color: Theme.steampunk ? Theme.alpha(Theme.accent, okMa.containsMouse ? 0.32 : 0.2)
                                           : Theme.alpha(Theme.accent, okMa.containsMouse ? 1.0 : 0.92)
                    border.width: Theme.steampunk ? 1.6 : 0
                    border.color: Theme.alpha(Theme.accent, 0.95)
                    // steampunk: a rivet in each rounded end
                    Repeater {
                        model: Theme.steampunk ? 2 : 0
                        Screw {
                            required property int index
                            size: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: index ? okBtn.width - 13 - width / 2 : 13 - width / 2
                            color: Theme.alpha(Theme.accent, 0.9)
                        }
                    }
                    Text { anchors.centerIn: parent; text: "Authenticate"
                           color: Theme.steampunk ? Qt.lighter(Theme.accent, 1.25) : Theme.current.onAccent; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                    MouseArea { id: okMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Polkit.submit(pw.text) }
                }
            }
        }
    
        // steampunk: the frame assembles with the reveal
        BrassFrame {
            anchors.fill: parent
            anchors.margins: 6
            radius: Math.max(4, pkPanel.radius - 6)
            color: Theme.alpha(Theme.accent, 0.72)
            corners: ["cross", "cross", "cog", "cog"]
            plate: "bottom"
            rail: false
            build: win.spReveal
            spin: win.spReveal * 160
        }
        // cyberpunk: the HUD frame traces itself round with the reveal
        CyberFrame {
            anchors.fill: parent
            anchors.margins: 6
            cut: Theme.cyberCut - 2.5
            color: Theme.alpha(Theme.accent, 0.75)
            cuts: [true, false, true, false]
            corners: ["none", "wedge", "none", "wedge"]
            bar: "top"; tab: "none"; rail: false
            build: win.spReveal
        }
    }
}
