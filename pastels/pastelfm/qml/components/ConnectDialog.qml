import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelFM
import pasteltheme

// Connect to an SSH (sftp/sshfs) or Samba (smb/cifs) share.
Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 440
    padding: 20
    closePolicy: Popup.CloseOnEscape

    property string mode: "ssh"   // "ssh" | "samba"

    function openWith(m) { mode = m; open() }
    function fieldStyle(f) {}

    background: Rectangle {
        radius: Theme.radius
        color: Theme.current.surface
        border.color: Theme.current.border
        border.width: 1
    }

    component Field: Rectangle {
        property alias placeholder: inp.placeholderText
        property alias text: inp.text
        property alias echoMode: inp.echoMode
        property alias input: inp
        Layout.fillWidth: true
        height: 38
        radius: Theme.radiusSm
        color: Theme.current.panel
        border.color: inp.activeFocus ? Theme.current.accent : Theme.current.border
        border.width: 1
        TextField {
            id: inp
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextField.AlignVCenter
            color: Theme.current.text
            placeholderTextColor: Theme.current.subtext
            background: Item {}
            selectByMouse: true
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        // Mode switch
        RowLayout {
            spacing: 8
            Repeater {
                model: [ {k:"ssh", t:"🔐 SSH / SFTP"}, {k:"samba", t:"🖧 Samba / SMB"} ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 40
                    radius: Theme.radiusSm
                    color: root.mode === modelData.k ? Theme.current.accent : Theme.current.panel
                    border.color: Theme.current.border
                    border.width: root.mode === modelData.k ? 0 : 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: root.mode === modelData.k ? Theme.current.onAccent : Theme.current.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mode = modelData.k
                    }
                }
            }
        }

        Field { id: hostF; placeholder: "Host  (e.g. 192.168.1.10 or server.local)" }

        // SSH-only row: port + remote path
        RowLayout {
            visible: root.mode === "ssh"
            spacing: 8
            Field { id: portF; placeholder: "Port (22)"; Layout.preferredWidth: 110; Layout.fillWidth: false }
            Field { id: remoteF; placeholder: "Remote path (/)" }
        }

        // Samba-only row: share + domain
        Field { id: shareF; visible: root.mode === "samba"; placeholder: "Share name  (e.g. media)" }
        Field { id: domainF; visible: root.mode === "samba"; placeholder: "Domain / Workgroup (optional)" }

        Field { id: userF; placeholder: "Username (optional)" }
        Field { id: passF; placeholder: "Password (optional)"; echoMode: TextInput.Password }
        Field { id: labelF; placeholder: "Bookmark label (optional)" }

        RowLayout {
            CheckBox {
                id: saveChk
                text: "Save connection"
                contentItem: Text {
                    text: saveChk.text
                    color: Theme.current.text
                    leftPadding: saveChk.indicator.width + 6
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            visible: root.mode === "ssh" && !Mounts.gioAvailable && !Mounts.sshfsAvailable
            wrapMode: Text.Wrap
            color: Theme.current.danger
            font.pixelSize: 12
            text: "Neither gvfs nor sshfs is installed — SSH mounting will not work. Install sshfs."
        }

        RowLayout {
            Layout.topMargin: 4
            PastelButton { text: "Cancel"; flat: true; onClicked: root.close() }
            Item { Layout.fillWidth: true }
            PastelButton {
                text: "Connect"
                iconText: "→"
                onClicked: {
                    var label = labelF.text
                    if (root.mode === "ssh") {
                        var port = parseInt(portF.text)
                        if (isNaN(port)) port = 22
                        Mounts.mountSsh(hostF.text, port, userF.text,
                                        remoteF.text, passF.text, label)
                        if (saveChk.checked)
                            Settings.addConnection({ type:"ssh", label:label, host:hostF.text,
                                port:port, user:userF.text, remotePath:remoteF.text })
                    } else {
                        Mounts.mountSamba(hostF.text, shareF.text, userF.text,
                                          passF.text, domainF.text, label)
                        if (saveChk.checked)
                            Settings.addConnection({ type:"samba", label:label, host:hostF.text,
                                share:shareF.text, user:userF.text, domain:domainF.text })
                    }
                    root.close()
                }
            }
        }
    }
}
