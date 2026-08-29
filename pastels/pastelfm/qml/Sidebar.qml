import QtQuick
import QtQuick.Controls.Basic
import PastelFM
import "components"
import pasteltheme

// Left navigation: Places, Bookmarks, Saved Connections, Active Mounts.
Rectangle {
    id: side
    property var view                 // active FileView, for navigation
    property var renameDialog         // shared RenameDialog from Main
    signal newConnection()

    color: Theme.alpha(Theme.current.sidebar, Theme.glassOpacity)
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.strokeGlass }

    function nav(p) { if (view) view.navigate(p) }

    component SectionLabel: Text {
        color: Theme.current.subtext
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        leftPadding: 14
        topPadding: 12
        bottomPadding: 4
    }

    component NavRow: Rectangle {
        id: nr
        property string iconName: ""
        property string label: ""
        property bool active: false
        signal clicked()
        signal secondary()
        width: parent ? parent.width : 0
        height: 34
        radius: Theme.radiusSm
        color: nr.active ? Theme.alpha(Theme.accent, 0.20)
               : (rowMa.containsMouse ? Theme.current.hover : "transparent")
        border.width: 1
        border.color: nr.active ? Theme.alpha(Theme.accent, 0.5) : "transparent"
        Row {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 8
            spacing: 9
            Item {
                width: 20; height: parent.height
                IconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: nr.iconName
                    color: nr.active ? Theme.accent : Theme.current.text
                    size: 18
                }
            }
            Text {
                width: parent.width - 34
                anchors.verticalCenter: parent.verticalCenter
                text: nr.label
                color: nr.active ? Theme.accent : Theme.current.text
                font.pixelSize: 13; elide: Text.ElideRight
            }
        }
        MouseArea {
            id: rowMa; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => { if (m.button === Qt.RightButton) nr.secondary(); else nr.clicked() }
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 6
        contentHeight: col.height
        clip: true
        ScrollBar.vertical: ScrollBar {}
        Column {
            id: col
            width: side.width
            spacing: 1
            padding: 6

            SectionLabel { text: "Places" }
            NavRow { iconName: "home"; label: "Home"; onClicked: side.view && side.view.goHome() }
            NavRow { iconName: "drive"; label: "Root"; onClicked: side.view && side.view.goRoot() }
            NavRow { iconName: "document"; label: "Documents"; onClicked: side.view && side.nav(side.view.homeSub("Documents")) }
            NavRow { iconName: "download"; label: "Downloads"; onClicked: side.view && side.nav(side.view.homeSub("Downloads")) }

            SectionLabel { text: "Bookmarks" }
            Repeater {
                model: Settings.bookmarks
                delegate: NavRow {
                    required property var modelData
                    iconName: "bookmark"
                    label: modelData.name
                    onClicked: side.nav(modelData.path)
                    onSecondary: Settings.removeBookmark(modelData.path)
                }
            }
            Text {
                visible: Settings.bookmarks.length === 0
                text: "  Right-click a folder tab\n  or use ✚ to bookmark"
                color: Theme.current.subtext; font.pixelSize: 11; leftPadding: 14; topPadding: 2
            }

            SectionLabel { text: "Saved connections" }
            Repeater {
                model: Settings.connections
                delegate: NavRow {
                    required property var modelData
                    required property int index
                    iconName: modelData.type === "ssh" ? "lock" : "server"
                    label: modelData.label && modelData.label.length ? modelData.label
                           : (modelData.host + (modelData.share ? "/" + modelData.share : ""))
                    onClicked: {
                        if (modelData.type === "ssh")
                            Mounts.mountSsh(modelData.host, modelData.port || 22, modelData.user || "",
                                            modelData.remotePath || "", "", label)
                        else
                            Mounts.mountSamba(modelData.host, modelData.share || "", modelData.user || "",
                                              "", modelData.domain || "", label)
                    }
                    onSecondary: rowMenu.openFor("conn", index, label)
                }
            }
            NavRow { iconName: "plus"; label: "Add connection…"; onClicked: side.newConnection() }

            SectionLabel { text: "Mounted"; visible: Mounts.count > 0 }
            Repeater {
                model: Mounts
                delegate: NavRow {
                    iconName: model.type === "ssh" ? "globe" : "monitor"
                    label: model.label
                    onClicked: side.nav(model.localPath)
                    onSecondary: rowMenu.openFor("mount", index, model.label)
                }
            }
        }
    }

    // Context menu for saved connections / active mounts.
    Menu {
        id: rowMenu
        property string kind: ""      // "conn" | "mount"
        property int idx: -1
        property string label: ""

        function openFor(k, i, l) {
            kind = k; idx = i; label = l
            popup()
        }
        function doRename() {
            var k = kind, i = idx, l = label
            side.renameDialog.openFor("", l)
            side.renameDialog.accepted.connect(function once(n) {
                side.renameDialog.accepted.disconnect(once)
                if (k === "conn") Settings.renameConnection(i, n)
                else Mounts.renameMount(i, n)
            })
        }

        background: Rectangle {
            implicitWidth: 180
            radius: Theme.radiusSm
            color: Theme.current.surface
            border.color: Theme.current.border
            border.width: 1
        }

        component MItem: MenuItem {
            id: mi
            contentItem: Text {
                text: mi.text
                color: mi.enabled ? Theme.current.text : Theme.current.subtext
                font.pixelSize: 13
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: mi.highlighted ? Theme.current.hover : "transparent"; radius: 6 }
        }

        MItem { text: "Rename…"; onTriggered: rowMenu.doRename() }
        MenuSeparator {}
        MItem {
            text: rowMenu.kind === "mount" ? "Unmount" : "Remove"
            onTriggered: {
                if (rowMenu.kind === "mount") Mounts.unmount(rowMenu.idx)
                else Settings.removeConnection(rowMenu.idx)
            }
        }
    }
}
