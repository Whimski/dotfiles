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
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    GlassPanel {
        id: pkPanel
        anchors.centerIn: parent
        width: 440
        height: col.implicitHeight + 36
        radius: Theme.radius
        glow: 0.6
        // quick scale + fade in/out from the centre
        scale: win.open ? 1 : 0.88
        opacity: win.open ? 1 : 0
        // springy pop on open, quick tuck on close
        Behavior on scale { NumberAnimation { duration: win.open ? Theme.animSlow : Theme.animMed
                                                easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.5 } }
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
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
            Rectangle {
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

                Rectangle {
                    width: 92; height: 34; radius: 9
                    color: cancelMa.containsMouse ? Theme.alpha(Theme.current.hover, 0.8) : Theme.alpha(Theme.current.hover, 0.5)
                    border.width: 1; border.color: Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font.pixelSize: Theme.fontSize - 2 }
                    MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Polkit.cancel() }
                }
                Rectangle {
                    width: 118; height: 34; radius: 9
                    color: Theme.alpha(Theme.accent, okMa.containsMouse ? 1.0 : 0.92)
                    Text { anchors.centerIn: parent; text: "Authenticate"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 2; font.weight: Font.DemiBold }
                    MouseArea { id: okMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Polkit.submit(pw.text) }
                }
            }
        }
    }
}
