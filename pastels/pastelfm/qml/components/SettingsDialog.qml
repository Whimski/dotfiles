import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import PastelFM
import pasteltheme

// App settings: pastel theme, light/dark/auto mode, and window transparency.
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
        property string target: ""   // "primary" | "secondary"
        onAccepted: {
            if (target === "secondary") Settings.customSecondary = selectedColor
            else Settings.customPrimary = selectedColor
        }
    }

    component SectionLabel: Text {
        color: Theme.current.subtext
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    contentItem: ColumnLayout {
        spacing: 14

        Text {
            text: "Settings"
            color: Theme.current.text
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.current.border }

        // -------- Pastel theme --------
        SectionLabel { text: "Pastel theme" }
        Grid {
            Layout.fillWidth: true
            columns: 3
            spacing: 10
            Repeater {
                model: Theme.order
                delegate: Rectangle {
                    required property string modelData
                    width: 116; height: 56
                    radius: Theme.radiusSm
                    color: Theme.swatchOf(modelData)
                    border.width: Theme.name === modelData ? 3 : 1
                    border.color: Theme.name === modelData ? Theme.current.text : Theme.current.border
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#2c2436"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Settings.theme = modelData; Theme.name = modelData }
                    }
                    Behavior on border.width { NumberAnimation { duration: Theme.animFast } }
                }
            }

            // Custom palette tile (user-chosen accent pair).
            Rectangle {
                width: 116; height: 56; radius: Theme.radiusSm
                color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
                border.width: Theme.name === "Custom" ? 3 : 1
                border.color: Theme.name === "Custom" ? Theme.current.text : Theme.strokeGlass
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle { width: 16; height: 16; radius: 8; color: Settings.customPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 16; height: 16; radius: 8; color: Settings.customSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Custom"; font.pixelSize: 13; color: Theme.current.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { Settings.theme = "Custom"; Theme.name = "Custom" } }
            }
        }

        // -------- Custom accents (only for the Custom palette) --------
        RowLayout {
            Layout.fillWidth: true
            visible: Theme.name === "Custom"
            Text { text: "Custom accents"; color: Theme.current.text; font.pixelSize: 14; Layout.fillWidth: true }
            Rectangle {
                width: 30; height: 24; radius: 7; color: Settings.customPrimary
                border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "primary"; colorDialog.selectedColor = Settings.customPrimary; colorDialog.open() } }
            }
            Rectangle {
                width: 30; height: 24; radius: 7; color: Settings.customSecondary
                border.color: Theme.strokeGlass; border.width: 1
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { colorDialog.target = "secondary"; colorDialog.selectedColor = Settings.customSecondary; colorDialog.open() } }
            }
        }

        // -------- Appearance (light / dark / auto) --------
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
                    Text {
                        anchors.centerIn: parent; text: modelData[1]
                        color: Settings.mode === modelData[0] ? Theme.current.onAccent : Theme.current.text
                        font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.mode = modelData[0] }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        // -------- Transparency --------
        RowLayout {
            Layout.fillWidth: true
            SectionLabel { text: "Window transparency"; Layout.fillWidth: true }
            Text {
                text: (100 - Settings.windowOpacity) + "%"
                color: Theme.current.subtext
                font.pixelSize: 12
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "Clear"; color: Theme.current.subtext; font.pixelSize: 11 }
            Slider {
                id: opacitySlider
                Layout.fillWidth: true
                from: 50; to: 100; stepSize: 1
                value: Settings.windowOpacity
                onMoved: Settings.windowOpacity = Math.round(value)

                background: Rectangle {
                    x: opacitySlider.leftPadding
                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                    width: opacitySlider.availableWidth
                    height: 5
                    radius: 3
                    color: Theme.current.panel
                    Rectangle {
                        // Filled portion represents "more solid".
                        width: opacitySlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: Theme.current.accent
                    }
                }
                handle: Rectangle {
                    x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                    width: 20; height: 20; radius: 10
                    color: Theme.current.surface
                    border.color: Theme.current.accent
                    border.width: 2
                }
            }
            Text { text: "Solid"; color: Theme.current.subtext; font.pixelSize: 11 }
        }
        Text {
            Layout.fillWidth: true
            text: "Requires a compositor with transparency (most Wayland/X11 desktops)."
            color: Theme.current.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.topMargin: 4
            Item { Layout.fillWidth: true }
            PastelButton { text: "Done"; onClicked: root.close() }
        }
    }
}
