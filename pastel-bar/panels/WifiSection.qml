import QtQuick
import ".."
import "../components"
import "../services"

// Wi-Fi network list. Header (label + rescan) over a list of networks: signal
// bars, SSID, lock (secured) and check (active). Tapping a secured network
// reveals an inline password field + Connect; open networks connect on tap.
Column {
    id: sec
    spacing: 6
    property var pending: null          // network awaiting a password
    property Item kbReturnTarget: null  // item to refocus after leaving the password field
    property Item pwInput: null         // the currently-visible password TextInput, if any

    Row {
        width: parent.width
        Text {
            text: "Networks"
            color: Theme.text
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            width: parent.width - 24
        }
        IconGlyph {
            name: "refresh"; size: 16
            color: Theme.subtext
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Net.rescan() }
        }
    }

    Text {
        visible: !Net.enabled || Net.networks.length === 0
        text: !Net.available ? "Networking unavailable"
             : !Net.enabled ? "Wi-Fi is off" : "No networks found"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: Net.enabled ? Net.networks : []
        delegate: Column {
            id: net
            required property var modelData
            width: sec.width
            spacing: 4
            readonly property bool secured: modelData.security !== undefined && modelData.security !== 0
            readonly property bool isActive: modelData.connected === true

            CyberRect {
                width: parent.width
                radius: Theme.radiusSm
                height: 38
                color: isActive ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.current.hover, 0.4)
                border.width: 1
                border.color: isActive ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 9
                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        level: modelData.signalStrength > 1 ? modelData.signalStrength / 100 : modelData.signalStrength
                        active: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || "(hidden)"
                        color: Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        width: parent.width - 90
                    }
                    IconGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: net.secured
                        name: "lock"; size: 13; color: Theme.subtext
                    }
                    IconGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: net.isActive
                        name: "check"; size: 15; color: Theme.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.isActive) { Net.disconnect(modelData); return }
                        if (parent.secured) sec.pending = (sec.pending === modelData ? null : modelData)
                        else Net.connect(modelData, "")
                    }
                }
            }

            // inline password entry for the pending secured network
            CyberRect {
                width: parent.width
                visible: sec.pending === modelData
                onVisibleChanged: if (visible) sec.pwInput = pw
                radius: Theme.radiusSm
                height: 38
                color: Theme.alpha(Theme.current.surface, 0.6)
                border.width: 1
                border.color: Theme.strokeGlass

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8
                    TextInput {
                        id: pw
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 78
                        color: Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        echoMode: TextInput.Password
                        clip: true
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Password"
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSize - 1
                            visible: pw.text === "" && !pw.activeFocus
                        }
                        onAccepted: {
                            Net.connect(modelData, text); sec.pending = null
                            if (sec.kbReturnTarget) sec.kbReturnTarget.forceActiveFocus()
                        }
                        Keys.onEscapePressed: if (sec.kbReturnTarget) sec.kbReturnTarget.forceActiveFocus()
                    }
                    CyberRect {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64; height: 26; radius: 8
                        color: Theme.alpha(Theme.accent, 0.92)
                        Text { anchors.centerIn: parent; text: "Connect"; color: Theme.current.onAccent; font.pixelSize: Theme.fontSize - 3; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Net.connect(modelData, pw.text); sec.pending = null } }
                    }
                }
            }
        }
    }
}
