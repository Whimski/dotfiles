import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelFM
import "components"
import pasteltheme

// Top navigation bar bound to the active FileView (`view`).
Rectangle {
    id: bar
    property var view
    signal connectClicked()
    signal settingsClicked()

    function focusFilter() { search.forceActiveFocus(); search.selectAll() }

    implicitHeight: 58
    color: Theme.alpha(Theme.current.surface, Theme.glassOpacity)

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.strokeGlass }

    component IconBtn: Rectangle {
        id: ib
        property string iconName: ""
        property bool enabled: true
        signal clicked()
        width: 38; height: 38
        radius: Theme.radiusSm
        color: ma.containsMouse && ib.enabled ? Theme.alpha(Theme.accent, 0.18) : "transparent"
        border.width: 1
        border.color: ma.containsMouse && ib.enabled ? Theme.alpha(Theme.accent, 0.45) : "transparent"
        opacity: ib.enabled ? 1.0 : 0.38
        IconGlyph { anchors.centerIn: parent; name: ib.iconName
                    color: ma.containsMouse && ib.enabled ? Theme.accent : Theme.current.text; size: 19 }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: ib.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (ib.enabled) ib.clicked()
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        IconBtn { iconName: "back"; enabled: bar.view ? bar.view.canBack : false; onClicked: bar.view.goBack() }
        IconBtn { iconName: "forward"; enabled: bar.view ? bar.view.canForward : false; onClicked: bar.view.goForward() }
        IconBtn { iconName: "up"; onClicked: if (bar.view) bar.view.goUp() }
        IconBtn { iconName: "home"; onClicked: if (bar.view) bar.view.goHome() }
        IconBtn { iconName: "refresh"; onClicked: if (bar.view) bar.view.refresh() }

        // Address / breadcrumb bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
            border.color: addr.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
            border.width: 1

            // Breadcrumb (shown when address not focused)
            Flickable {
                id: crumbFlick
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                visible: !addr.activeFocus
                contentWidth: crumbs.width
                clip: true
                Row {
                    id: crumbs
                    height: parent.height
                    spacing: 2
                    Repeater {
                        model: bar.view ? crumbSegments(bar.view.path) : []
                        delegate: Row {
                            required property var modelData
                            height: crumbs.height
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Theme.current.text
                                font.pixelSize: 13
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bar.view.navigate(modelData.path)
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "  ›  "
                                color: Theme.current.subtext
                                font.pixelSize: 13
                                visible: modelData.hasNext
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onDoubleClicked: { addr.text = bar.view.path; addr.forceActiveFocus(); addr.selectAll() }
                }
            }

            TextField {
                id: addr
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextField.AlignVCenter
                color: Theme.current.text
                background: Item {}
                opacity: activeFocus ? 1 : 0
                selectByMouse: true
                onAccepted: { if (bar.view) bar.view.navigate(text); focus = false }
                Keys.onEscapePressed: focus = false
            }
        }

        // Search filter
        Rectangle {
            Layout.preferredWidth: 170
            Layout.preferredHeight: 38
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
            border.color: search.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
            border.width: 1
            Row {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 8
                spacing: 6
                Text { text: "🔍"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: search
                    width: parent.width - 26
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: "Filter"
                    placeholderTextColor: Theme.current.subtext
                    color: Theme.current.text
                    background: Item {}
                    onTextChanged: if (bar.view) bar.view.setFilter(text)
                }
            }
        }

        IconBtn {
            iconName: Settings.viewMode === "grid" ? "list" : "grid"
            onClicked: Settings.viewMode = (Settings.viewMode === "grid" ? "list" : "grid")
        }
        IconBtn {
            iconName: Settings.showHidden ? "eye" : "eyeOff"
            onClicked: Settings.showHidden = !Settings.showHidden
        }
        IconBtn { iconName: "network"; onClicked: bar.connectClicked() }
        IconBtn { iconName: "settings"; onClicked: bar.settingsClicked() }
    }

    function crumbSegments(p) {
        if (!p) return []
        var parts = p.split("/").filter(function(x){ return x.length })
        var segs = []
        var acc = ""
        segs.push({ name: "/", path: "/", hasNext: parts.length > 0 })
        for (var i = 0; i < parts.length; ++i) {
            acc += "/" + parts[i]
            segs.push({ name: parts[i], path: acc, hasNext: i < parts.length - 1 })
        }
        return segs
    }
}
