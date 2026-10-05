import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import ".."
import "../services"

// Themed, in-shell wallpaper file browser — replaces the native/portal FileDialog
// so it matches the pastel glass look and offers a "show hidden" toggle and a
// grid/list view switch. Browses directories with FolderListModel, filters to image
// files, and writes the pick to Settings.setWallpaperFor(targetScreen, url).
Item {
    id: picker
    anchors.fill: parent
    visible: active
    z: 100

    property bool active: false
    property string targetScreen: ""
    property bool showHidden: false
    property bool gridMode: true

    readonly property string homeDir: (Quickshell.env("HOME") || "/home")

    function toUrl(p) { return "file://" + encodeURI(p) }
    function fromUrl(u) {
        var s = u ? u.toString() : ""
        if (s.indexOf("file://") === 0) s = s.substring(7)
        return decodeURIComponent(s)
    }

    function openFor(screen, startPath) {
        targetScreen = screen
        var p = startPath && startPath !== "" ? fromUrl(startPath) : (homeDir + "/Pictures")
        folderModel.folder = toUrl(p)
        active = true
    }

    // dim scrim; click outside the panel closes
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha("#000000", 0.45)
        MouseArea { anchors.fill: parent; onClicked: picker.active = false }
    }

    GlassPanel {
        id: panel
        anchors.centerIn: parent
        width: Math.min(720, picker.width - 80)
        height: Math.min(560, picker.height - 80)
        MouseArea { anchors.fill: parent }   // swallow clicks so the scrim doesn't close

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ---- header ----
            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // up / parent
                    CyberRect {
                        width: 34; height: 34; radius: Theme.radiusSm
                        color: upMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.5)
                        border.width: 1; border.color: Theme.strokeGlass
                        IconGlyph { anchors.centerIn: parent; name: "back"; size: 18; color: Theme.text }
                        MouseArea {
                            id: upMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (folderModel.parentFolder.toString() !== "") folderModel.folder = folderModel.parentFolder
                        }
                    }
                    // home
                    CyberRect {
                        width: 34; height: 34; radius: Theme.radiusSm
                        color: homeMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.5)
                        border.width: 1; border.color: Theme.strokeGlass
                        IconGlyph { anchors.centerIn: parent; name: "home"; size: 16; color: Theme.subtext }
                        MouseArea {
                            id: homeMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: folderModel.folder = picker.toUrl(picker.homeDir)
                        }
                    }
                }

                Text {
                    anchors.left: parent.left; anchors.leftMargin: 88
                    anchors.right: viewToggle.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.fromUrl(folderModel.folder)
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                    elide: Text.ElideLeft
                }

                // grid / list view toggle (segmented)
                CyberRect {
                    id: viewToggle
                    anchors.right: hiddenToggle.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34; radius: Theme.radiusSm
                    width: 68
                    color: Theme.alpha(Theme.current.panel, 0.5)
                    border.width: 1; border.color: Theme.strokeGlass
                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        Repeater {
                            model: [{ g: true, ic: "grid" }, { g: false, ic: "list" }]
                            delegate: CyberRect {
                                required property var modelData
                                width: (viewToggle.width - 6) / 2
                                height: parent.height
                                radius: Theme.radiusSm - 2
                                color: picker.gridMode === modelData.g ? Theme.alpha(Theme.current.accent, 0.28) : "transparent"
                                IconGlyph {
                                    anchors.centerIn: parent
                                    name: modelData.ic; size: 15
                                    color: picker.gridMode === modelData.g ? Theme.current.accent : Theme.subtext
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: picker.gridMode = modelData.g
                                }
                            }
                        }
                    }
                }

                // show-hidden toggle
                CyberRect {
                    id: hiddenToggle
                    anchors.right: closeBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34; radius: Theme.radiusSm
                    width: hiddenRow.implicitWidth + 20
                    color: picker.showHidden ? Theme.alpha(Theme.current.accent, 0.22)
                                             : (hidMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.5))
                    border.width: 1
                    border.color: picker.showHidden ? Theme.alpha(Theme.current.accent, 0.6) : Theme.strokeGlass
                    Row {
                        id: hiddenRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: picker.showHidden ? "eye" : "eyeOff"; size: 16
                            color: picker.showHidden ? Theme.current.accent : Theme.subtext
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Hidden"
                            color: picker.showHidden ? Theme.current.accent : Theme.subtext
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }
                    MouseArea {
                        id: hidMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.showHidden = !picker.showHidden
                    }
                }

                CyberRect {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34; height: 34; radius: Theme.radiusSm
                    color: closeMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.5)
                    border.width: 1; border.color: Theme.strokeGlass
                    IconGlyph { anchors.centerIn: parent; name: "close"; size: 16; color: Theme.text }
                    MouseArea {
                        id: closeMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.active = false
                    }
                }
            }

            // ---- files (grid or list) ----
            Item {
                id: viewArea
                width: parent.width
                height: parent.height - 46

                FolderListModel {
                    id: folderModel
                    folder: picker.toUrl(picker.homeDir + "/Pictures")
                    showDirs: true
                    showFiles: true
                    showDirsFirst: true
                    showDotAndDotDot: false
                    showHidden: picker.showHidden
                    sortField: FolderListModel.Name
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif"]
                }

                // grid view
                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: picker.gridMode
                    clip: true
                    cellWidth: Math.floor(width / Math.max(3, Math.floor(width / 150)))
                    cellHeight: 128
                    boundsBehavior: Flickable.StopAtBounds
                    model: folderModel

                    delegate: Item {
                        id: cell
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        width: grid.cellWidth
                        height: grid.cellHeight

                        CyberRect {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: Theme.radiusSm + 2
                            color: cellMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.55)
                            border.width: 1
                            border.color: cellMa.containsMouse ? Theme.alpha(Theme.current.accent, 0.5) : Theme.strokeGlass
                            clip: true

                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                visible: cell.fileIsDir
                                IconGlyph { anchors.horizontalCenter: parent.horizontalCenter; name: "folder"; size: 34; color: Theme.current.accent }
                                Text {
                                    width: cell.width - 24
                                    horizontalAlignment: Text.AlignHCenter
                                    text: cell.fileName
                                    color: Theme.text
                                    font.pixelSize: Theme.fontSize - 4
                                    elide: Text.ElideMiddle
                                }
                            }

                            Image {
                                anchors.fill: parent
                                visible: !cell.fileIsDir
                                source: cell.fileIsDir ? "" : picker.toUrl(cell.filePath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: 260
                                sourceSize.height: 220
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: !cell.fileIsDir
                                radius: Theme.radiusSm + 2
                                gradient: Gradient {
                                    GradientStop { position: 0.6; color: "transparent" }
                                    GradientStop { position: 1.0; color: Theme.alpha("#000000", 0.65) }
                                }
                            }
                            Text {
                                visible: !cell.fileIsDir
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
                                text: cell.fileName
                                color: "#ffffff"
                                font.pixelSize: Theme.fontSize - 5
                                elide: Text.ElideMiddle
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (cell.fileIsDir) {
                                        folderModel.folder = picker.toUrl(cell.filePath)
                                    } else {
                                        Settings.setWallpaperFor(picker.targetScreen, picker.toUrl(cell.filePath))
                                        picker.active = false
                                    }
                                }
                            }
                        }
                    }
                }

                // list view
                ListView {
                    id: listView
                    anchors.fill: parent
                    visible: !picker.gridMode
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: folderModel

                    delegate: CyberRect {
                        id: lrow
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        width: listView.width
                        height: 46
                        radius: Theme.radiusSm
                        color: lrowMa.containsMouse ? Theme.hover : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Item {
                                width: 34; height: 34
                                anchors.verticalCenter: parent.verticalCenter
                                IconGlyph {
                                    anchors.centerIn: parent
                                    visible: lrow.fileIsDir
                                    name: "folder"; size: 22; color: Theme.current.accent
                                }
                                CyberRect {
                                    anchors.fill: parent
                                    visible: !lrow.fileIsDir
                                    radius: Theme.radiusSm - 2
                                    clip: true
                                    color: Theme.alpha(Theme.current.panel, 0.55)
                                    border.width: 1; border.color: Theme.strokeGlass
                                    Image {
                                        anchors.fill: parent
                                        source: lrow.fileIsDir ? "" : picker.toUrl(lrow.filePath)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        sourceSize.width: 72; sourceSize.height: 72
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: listView.width - 74
                                text: lrow.fileName
                                color: Theme.text
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideMiddle
                            }
                        }

                        MouseArea {
                            id: lrowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (lrow.fileIsDir) {
                                    folderModel.folder = picker.toUrl(lrow.filePath)
                                } else {
                                    Settings.setWallpaperFor(picker.targetScreen, picker.toUrl(lrow.filePath))
                                    picker.active = false
                                }
                            }
                        }
                    }
                }

                // empty-folder hint
                Text {
                    anchors.centerIn: parent
                    visible: folderModel.count === 0
                    text: "No images or folders here"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
