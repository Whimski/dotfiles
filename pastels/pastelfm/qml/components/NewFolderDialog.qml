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
    width: 380
    padding: 20
    closePolicy: Popup.CloseOnEscape

    property bool fileMode: false
    signal accepted(string name)

    function openNew(asFile) {
        fileMode = asFile === true
        field.text = fileMode ? "new-file.txt" : "New Folder"
        open()
        field.forceActiveFocus()
        field.selectAll()
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.current.surface
        border.color: Theme.current.border
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 14
        Text {
            text: root.fileMode ? "New file" : "New folder"
            color: Theme.current.text; font.pixelSize: 16; font.weight: Font.DemiBold
        }
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: Theme.radiusSm
            color: Theme.current.panel
            border.color: field.activeFocus ? Theme.current.accent : Theme.current.border
            border.width: 1
            TextField {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextField.AlignVCenter
                color: Theme.current.text
                background: Item {}
                selectByMouse: true
                onAccepted: okBtn.clicked()
            }
        }
        RowLayout {
            PastelButton { text: "Cancel"; flat: true; onClicked: root.close() }
            Item { Layout.fillWidth: true }
            PastelButton {
                id: okBtn
                text: "Create"
                onClicked: {
                    if (field.text.trim().length > 0) {
                        root.accepted(field.text.trim())
                        root.close()
                    }
                }
            }
        }
    }
}
