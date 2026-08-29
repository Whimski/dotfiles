import QtQuick
import QtQuick.Layouts
import PastelImage
import pasteltheme

// Top chrome: open / browse / filename, and zoom-fit-rotate-save-settings.
Rectangle {
    id: bar
    signal requestOpen()
    signal requestSettings()
    signal requestSave()
    signal zoomIn()
    signal zoomOut()
    signal fitView()

    implicitHeight: 52
    color: Theme.alpha(Theme.current.surface, Theme.glassOpacity)
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.strokeGlass }

    component IconBtn: Rectangle {
        id: ib
        property string glyph: ""
        property bool enabled: true
        signal clicked()
        width: 34; height: 34; radius: Theme.radiusSm
        opacity: enabled ? 1 : 0.35
        color: ma.containsMouse && ib.enabled ? Theme.alpha(Theme.accent, 0.18) : "transparent"
        border.width: 1
        border.color: ma.containsMouse && ib.enabled ? Theme.alpha(Theme.accent, 0.45) : "transparent"
        IconGlyph { anchors.centerIn: parent; name: ib.glyph; size: 18
                    color: ma.containsMouse && ib.enabled ? Theme.accent : Theme.current.text }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: ib.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ib.enabled) ib.clicked() }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        // Open
        Rectangle {
            Layout.preferredHeight: 34
            Layout.preferredWidth: openRow.implicitWidth + 22
            radius: Theme.radiusSm
            color: openMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
            Row { id: openRow; anchors.centerIn: parent; spacing: 7
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: "folder"; size: 16; color: Theme.current.onAccent }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Open"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold } }
            MouseArea { id: openMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.requestOpen() }
        }

        IconBtn { glyph: "chevronLeft"; enabled: Img.count > 1; onClicked: Img.prev() }
        IconBtn { glyph: "chevronRight"; enabled: Img.count > 1; onClicked: Img.next() }

        Column {
            Layout.leftMargin: 6
            spacing: 0
            Text { text: Img.hasImage ? Img.fileName : "No image"; color: Theme.current.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideMiddle; width: Math.min(implicitWidth, 320) }
            Text { visible: Img.count > 0; text: Img.index + " / " + Img.count; color: Theme.current.subtext; font.pixelSize: 11 }
        }

        Item { Layout.fillWidth: true }

        IconBtn { glyph: "zoomOut"; enabled: Img.hasImage; onClicked: bar.zoomOut() }
        IconBtn { glyph: "zoomIn"; enabled: Img.hasImage; onClicked: bar.zoomIn() }
        IconBtn { glyph: "fit"; enabled: Img.hasImage; onClicked: bar.fitView() }
        IconBtn { glyph: "rotate"; enabled: Img.hasImage; onClicked: Img.rotateCW() }

        Rectangle { Layout.leftMargin: 4; Layout.preferredWidth: 1; Layout.preferredHeight: 24; color: Theme.strokeGlass }

        // Save
        Rectangle {
            Layout.preferredHeight: 34
            Layout.preferredWidth: saveRow.implicitWidth + 20
            radius: Theme.radiusSm
            opacity: Img.hasImage ? 1 : 0.4
            color: saveMa.containsMouse && Img.hasImage ? Theme.alpha(Theme.current.hover, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
            border.width: 1; border.color: Theme.strokeGlass
            Row { id: saveRow; anchors.centerIn: parent; spacing: 7
                IconGlyph { anchors.verticalCenter: parent.verticalCenter; name: Settings.saveClipboardOnly ? "copy" : "download"; size: 15; color: Theme.current.text }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Settings.saveClipboardOnly ? "Copy" : "Save"; color: Theme.current.text; font.pixelSize: 13; font.weight: Font.DemiBold } }
            MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (Img.hasImage) bar.requestSave() }
        }

        IconBtn { glyph: "settings"; onClicked: bar.requestSettings() }
    }
}
