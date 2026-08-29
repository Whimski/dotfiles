import QtQuick
import QtQuick.Controls.Basic
import PastelFM
import pasteltheme

// A soft, rounded button used across the toolbar and dialogs.
Button {
    id: control

    property color accentColor: Theme.current.accent
    property string iconText: ""      // optional leading glyph/emoji
    // `flat` is inherited from Button and controls the ghost/solid look below.

    implicitHeight: 38
    implicitWidth: Math.max(38, contentItem.implicitWidth + 28)
    hoverEnabled: true

    contentItem: Row {
        spacing: control.text !== "" && control.iconText !== "" ? 7 : 0
        Text {
            visible: control.iconText !== ""
            text: control.iconText
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
            color: control.flat ? Theme.current.text : Theme.current.onAccent
        }
        Text {
            visible: control.text !== ""
            text: control.text
            font.pixelSize: 14
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            color: control.flat ? Theme.current.text : Theme.current.onAccent
        }
    }

    background: Rectangle {
        radius: Theme.radiusSm
        color: control.flat
               ? (control.hovered ? Theme.current.hover : "transparent")
               : (control.down ? Qt.darker(control.accentColor, 1.12)
                               : control.hovered ? Qt.lighter(control.accentColor, 1.06)
                                                 : control.accentColor)
        border.color: control.flat ? Theme.current.border : "transparent"
        border.width: control.flat ? 1 : 0
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
}
