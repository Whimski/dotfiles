import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import ".."
import "../services"

// Themed, in-shell wallpaper file browser — replaces the native/portal FileDialog
// so it matches the pastel glass look and offers a "show hidden" toggle. Browses
// directories with FolderListModel, filters to image files, and writes the pick to
// Settings.setWallpaperFor(targetScreen, url).
Item {
    id: picker
    anchors.fill: parent
    visible: active
    z: 100

    property bool active: false
    property string targetScreen: ""
    property bool showHidden: false

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
        // strip trailing filename if a file path was passed
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
        // swallow clicks so the scrim doesn't close when interacting
        MouseArea { anchors.fill: parent }

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
                    Rectangle {
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
                    Rectangle {
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
                    anchors.right: hiddenToggle.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.fromUrl(folderModel.folder)
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 3
                    elide: Text.ElideLeft
                }

                // show-hidden toggle
                Rectangle {
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

                Rectangle {
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

            // ---- grid ----
            GridView {
                id: grid
                width: parent.width
                height: parent.height - 46
                clip: true
                cellWidth: Math.floor(width / Math.max(3, Math.floor(width / 150)))
                cellHeight: 128
                boundsBehavior: Flickable.StopAtBounds

                model: FolderListModel {
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

                delegate: Item {
                    id: cell
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: Theme.radiusSm + 2
                        color: cellMa.containsMouse ? Theme.hover : Theme.alpha(Theme.current.panel, 0.55)
                        border.width: 1
                        border.color: cellMa.containsMouse ? Theme.alpha(Theme.current.accent, 0.5) : Theme.strokeGlass
                        clip: true

                        // folder tile
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

                        // image thumbnail
                        Image {
                            id: thumb
                            anchors.fill: parent
                            visible: !cell.fileIsDir
                            source: cell.fileIsDir ? "" : picker.toUrl(cell.filePath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 260
                            sourceSize.height: 220
                        }
                        // filename scrim for images
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

                // empty-folder hint
                Text {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: "No images or folders here"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
