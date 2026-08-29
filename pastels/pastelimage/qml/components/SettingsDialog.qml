import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import PastelImage
import pasteltheme

// Theme picker (palette / light-dark-auto / custom accents / transparency) plus
// the viewer background style.
Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 440
    padding: 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        radius: Theme.radius
        color: Theme.glassBg
        border.color: Theme.alpha(Theme.glow, 0.5)
        border.width: 1
    }

    ColorDialog {
        id: colorDialog
        property string target: ""
        onAccepted: {
            if (target === "secondary") Settings.customSecondary = selectedColor
            else Settings.customPrimary = selectedColor
        }
    }

    component SectionLabel: Text {
        color: Theme.current.subtext; font.pixelSize: 11; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text { text: "Settings"; color: Theme.current.text; font.pixelSize: 18; font.weight: Font.DemiBold }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- background ----
        SectionLabel { text: "Canvas background" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["theme", "Theme"], ["dark", "Dark"], ["checker", "Checker"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.radiusSm
                    color: Settings.background === modelData[0] ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
                    border.width: 1
                    border.color: Settings.background === modelData[0] ? "transparent" : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: modelData[1]
                           color: Settings.background === modelData[0] ? Theme.current.onAccent : Theme.current.text
                           font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.background = modelData[0] }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- saving ----
        SectionLabel { text: "Saving" }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Save to clipboard only"; color: Theme.current.text; font.pixelSize: 14; Layout.fillWidth: true }
            Rectangle {
                width: 44; height: 24; radius: 12
                color: Settings.saveClipboardOnly ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
                border.width: 1; border.color: Theme.strokeGlass
                Rectangle {
                    width: 18; height: 18; radius: 9; color: Theme.dark ? "#e9e9ef" : "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: Settings.saveClipboardOnly ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.saveClipboardOnly = !Settings.saveClipboardOnly }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Save (Ctrl+S) copies the edited image to the clipboard instead of writing a PNG file."
            color: Theme.current.subtext; font.pixelSize: 11; wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // ---- palette ----
        SectionLabel { text: "Pastel theme" }
        Grid {
            Layout.fillWidth: true
            columns: 3
            spacing: 10
            Repeater {
                model: Theme.order
                delegate: Rectangle {
                    required property string modelData
                    width: 128; height: 46; radius: Theme.radiusSm
                    color: Theme.swatchOf(modelData)
                    border.width: Theme.name === modelData ? 3 : 1
                    border.color: Theme.name === modelData ? Theme.current.text : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 13; font.weight: Font.Medium; color: "#2c2436" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Settings.theme = modelData; Theme.name = modelData } }
                }
            }
            Rectangle {
                width: 128; height: 46; radius: Theme.radiusSm
                color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
                border.width: Theme.name === "Custom" ? 3 : 1
                border.color: Theme.name === "Custom" ? Theme.current.text : Theme.strokeGlass
                Row { anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 15; height: 15; radius: 8; color: Settings.customPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 15; height: 15; radius: 8; color: Settings.customSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Custom"; font.pixelSize: 13; color: Theme.current.text; anchors.verticalCenter: parent.verticalCenter } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Settings.theme = "Custom"; Theme.name = "Custom" } }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: Theme.name === "Custom"
            Text { text: "Custom accents"; color: Theme.current.text; font.pixelSize: 14; Layout.fillWidth: true }
            Rectangle { width: 30; height: 24; radius: 7; color: Settings.customPrimary; border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "primary"; colorDialog.selectedColor = Settings.customPrimary; colorDialog.open() } } }
            Rectangle { width: 30; height: 24; radius: 7; color: Settings.customSecondary; border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "secondary"; colorDialog.selectedColor = Settings.customSecondary; colorDialog.open() } } }
        }

        // ---- appearance ----
        SectionLabel { text: "Appearance" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [["light", "Light"], ["dark", "Dark"], ["auto", "Auto"]]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.radiusSm
                    color: Settings.mode === modelData[0] ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
                    border.width: 1
                    border.color: Settings.mode === modelData[0] ? "transparent" : Theme.strokeGlass
                    Text { anchors.centerIn: parent; text: modelData[1]
                           color: Settings.mode === modelData[0] ? Theme.current.onAccent : Theme.current.text
                           font.pixelSize: 13; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.mode = modelData[0] }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        RowLayout {
            Layout.topMargin: 4
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 34; Layout.preferredWidth: 84; radius: Theme.radiusSm
                color: doneMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                Text { anchors.centerIn: parent; text: "Done"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: doneMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
        }
    }
}
