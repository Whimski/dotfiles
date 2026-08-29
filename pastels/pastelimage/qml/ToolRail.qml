import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import PastelImage
import pasteltheme

// Left editor panel: tool selection, brush size, pen colour, undo/clear.
Rectangle {
    id: rail
    implicitWidth: 168

    property string tool: "view"
    property color brushColor: "#ff5c8a"
    property int brushSize: 26
    property bool canUndo: false

    signal toolSelected(string t)
    signal colorSelected(color c)
    signal sizeSelected(int s)
    signal undo()
    signal clearEdits()

    color: Theme.alpha(Theme.current.sidebar, Theme.glassOpacity)
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.strokeGlass }

    readonly property var _swatches: ["#ff5c8a", "#ff4d4d", "#ffb84d", "#ffe14d",
                                      "#54d17f", "#4da6ff", "#b784f0", "#ffffff", "#0e0e12"]

    component Label: Text {
        color: Theme.current.subtext; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
    }
    component ToolBtn: Rectangle {
        id: tb
        property string glyph: ""
        property string label: ""
        property string id: ""
        Layout.fillWidth: true
        height: 38
        radius: Theme.radiusSm
        readonly property bool active: rail.tool === tb.id
        color: active ? Theme.alpha(Theme.accent, 0.9)
               : (tbMa.containsMouse ? Theme.current.hover : "transparent")
        border.width: 1
        border.color: active ? "transparent" : Theme.strokeGlass
        Row {
            anchors.fill: parent; anchors.leftMargin: 12; spacing: 10
            IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: tb.glyph; size: 18
                        color: tb.active ? Theme.current.onAccent : Theme.current.text }
            Text { anchors.verticalCenter: parent.verticalCenter; text: tb.label
                   color: tb.active ? Theme.current.onAccent : Theme.current.text
                   font.pixelSize: 13; font.weight: tb.active ? Font.DemiBold : Font.Normal }
        }
        MouseArea { id: tbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rail.toolSelected(tb.id) }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Label { text: "TOOLS" }
        ToolBtn { glyph: "move"; label: "View"; id: "view" }
        ToolBtn { glyph: "edit"; label: "Pen";  id: "pen" }
        ToolBtn { glyph: "blur"; label: "Blur"; id: "blur" }

        // brush size (pen only)
        ColumnLayout {
            Layout.fillWidth: true
            visible: rail.tool === "pen"
            spacing: 6
            Label { text: "BRUSH SIZE" }
            GlassSlider {
                Layout.fillWidth: true
                from: 4; to: 160; value: rail.brushSize; suffix: " px"
                onMoved: (v) => rail.sizeSelected(Math.round(v))
            }
        }

        // blur hint
        Text {
            Layout.fillWidth: true
            visible: rail.tool === "blur"
            text: "Drag a box over an area to blur it. Add as many as you like; Undo removes the last."
            color: Theme.current.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // pen colour
        ColumnLayout {
            Layout.fillWidth: true
            visible: rail.tool === "pen"
            spacing: 6
            Label { text: "COLOUR" }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: rail._swatches
                    delegate: Rectangle {
                        required property var modelData
                        width: 22; height: 22; radius: 6
                        color: modelData
                        border.width: Qt.colorEqual(rail.brushColor, modelData) ? 3 : 1
                        border.color: Qt.colorEqual(rail.brushColor, modelData) ? Theme.current.text : Theme.strokeGlass
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rail.colorSelected(modelData) }
                    }
                }
                // custom colour
                Rectangle {
                    width: 22; height: 22; radius: 6
                    color: "transparent"; border.width: 1; border.color: Theme.strokeGlass
                    IconGlyph { anchors.centerIn: parent; name: "plus"; size: 13; color: Theme.current.subtext }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { colorDialog.selectedColor = rail.brushColor; colorDialog.open() } }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.strokeGlass }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; height: 32; radius: Theme.radiusSm
                opacity: rail.canUndo ? 1 : 0.4
                color: undoMa.containsMouse && rail.canUndo ? Theme.current.hover : "transparent"
                border.width: 1; border.color: Theme.strokeGlass
                Row { anchors.centerIn: parent; spacing: 6
                    IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "back"; size: 14; color: Theme.current.text }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Undo"; color: Theme.current.text; font.pixelSize: 12 } }
                MouseArea { id: undoMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (rail.canUndo) rail.undo() }
            }
            Rectangle {
                Layout.preferredWidth: 34; height: 32; radius: Theme.radiusSm
                color: clrMa.containsMouse ? Theme.alpha(Theme.current.danger, 0.2) : "transparent"
                border.width: 1; border.color: Theme.strokeGlass
                IconGlyph { anchors.centerIn: parent; name: "trash"; size: 15; color: clrMa.containsMouse ? Theme.current.danger : Theme.current.subtext }
                MouseArea { id: clrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rail.clearEdits() }
            }
        }
    }

    ColorDialog {
        id: colorDialog
        onAccepted: rail.colorSelected(selectedColor)
    }
}
