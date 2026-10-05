import QtQuick
import ".."
import "../components"
import "../services"

// Bluetooth device list. Header (label + scan) over device rows: name, state and
// battery. Tap connects/disconnects (pairs first if unpaired).
Column {
    id: sec
    spacing: 6

    Row {
        width: parent.width
        Text {
            text: "Devices"
            color: Theme.text
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            width: parent.width - 24
        }
        IconGlyph {
            name: "refresh"; size: 16
            color: (BT.adapter && BT.adapter.discovering) ? Theme.accent : Theme.subtext
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: BT.startScan() }
        }
    }

    Text {
        visible: !BT.powered || BT.devices.length === 0
        text: !BT.available ? "Bluetooth unavailable"
             : !BT.powered ? "Bluetooth is off" : "No devices"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 2
    }

    Repeater {
        model: BT.powered ? BT.devices : []
        delegate: CyberRect {
            required property var modelData
            width: sec.width
            radius: Theme.radiusSm
            height: 40
            color: modelData.connected ? Theme.alpha(Theme.accent, 0.18) : Theme.alpha(Theme.current.hover, 0.4)
            border.width: 1
            border.color: modelData.connected ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 9
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bluetooth"; size: 16
                    color: modelData.connected ? Theme.accent : Theme.text
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                    Text {
                        text: modelData.name || modelData.address || "Device"
                        color: Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "")
                        visible: text !== ""
                        color: Theme.subtext
                        font.pixelSize: Theme.fontSize - 4
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.batteryAvailable
                    text: Math.round(modelData.battery * 100) + "%"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.connected) BT.disconnect(modelData)
                    else if (modelData.paired) BT.connect(modelData)
                    else BT.pair(modelData)
                }
            }
        }
    }
}
