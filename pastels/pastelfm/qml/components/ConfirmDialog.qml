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
    width: 400
    padding: 20
    closePolicy: Popup.CloseOnEscape

    property string heading: "Are you sure?"
    property string body: ""
    property string confirmText: "Confirm"
    property bool danger: false
    signal confirmed()

    function ask(h, b, c, isDanger) {
        heading = h; body = b; confirmText = c || "Confirm"; danger = isDanger === true
        open()
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.current.surface
        border.color: Theme.current.border
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 12
        Text { text: root.heading; color: Theme.current.text; font.pixelSize: 16; font.weight: Font.DemiBold }
        Text {
            Layout.fillWidth: true
            text: root.body
            visible: root.body !== ""
            color: Theme.current.subtext
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.topMargin: 4
            PastelButton { text: "Cancel"; flat: true; onClicked: root.close() }
            Item { Layout.fillWidth: true }
            PastelButton {
                text: root.confirmText
                accentColor: root.danger ? Theme.current.danger : Theme.current.accent
                onClicked: { root.confirmed(); root.close() }
            }
        }
    }
}
