import QtQuick
import Quickshell.Services.Pipewire
import ".."
import "../components"
import "../services"

// Audio settings surface: a large vertical volume "level tile" + connected
// device header, a segmented Outputs / Inputs / Streams selector, and a list of
// per-device cards each with its own volume slider + mute. Binds to the Audio
// service (Pipewire). Meant to live inside the TunePanel Audio Page.
Column {
    id: root
    width: parent ? parent.width : 400
    spacing: 16

    property string tab: "out"     // "out" | "in" | "streams"
    property string filter: ""     // search text from the settings bar

    // Exposed so a caller (TunePanel's hint mode) can hint these sub-items
    // individually rather than the whole component.
    property alias muteItem: muteIcon
    property alias tabsRepeater: tabsRep
    property alias devicesRepeater: devicesRep

    // Pick a glyph for an audio node from its name/description (headphones,
    // hdmi/monitor, speakers…).
    function _audioIcon(node) {
        if (!node) return "volume"
        var s = ((node.name || "") + " " + (node.description || "")).toLowerCase()
        if (s.indexOf("bluez") >= 0 || s.indexOf("headphone") >= 0
            || s.indexOf("headset") >= 0 || s.indexOf("bluetooth") >= 0) return "headphones"
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0) return "monitor"
        return "volume"   // analog / speakers default
    }

    // A compact inline volume slider (0..1) with a % readout. Reused by the
    // header and the per-device cards.
    component MiniSlider: Item {
        id: ms
        property real value: 0
        property color accent: Theme.accent
        signal moved(real v)
        implicitHeight: 22
        readonly property real _frac: Math.max(0, Math.min(1, value))

        CyberRect {
            id: track
            anchors.left: parent.left
            anchors.right: pct.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 6; radius: 3
            color: Theme.alpha(Theme.subtext, 0.3)
            CyberRect {
                height: parent.height; radius: parent.radius
                width: parent.width * ms._frac
                color: ms.accent
            }
            CyberRect {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: (track.width - width) * ms._frac
                color: ms.accent
                border.width: 2; border.color: Theme.current.onAccent
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -7
                cursorShape: Qt.PointingHandCursor
                onPressed: (m) => ms._set(m.x)
                onPositionChanged: (m) => { if (pressed) ms._set(m.x) }
            }
        }
        Text {
            id: pct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            horizontalAlignment: Text.AlignRight
            text: Math.round(ms.value * 100) + "%"
            color: Theme.subtext
            font.pixelSize: Theme.fontSize - 2
            font.weight: Font.DemiBold
        }
        function _set(mx) {
            var t = Math.max(0, Math.min(1, mx / track.width))
            ms.value = t
            ms.moved(t)
        }
    }

    // A single selectable row ("Follow default output" / one sink) used by the
    // per-stream output picker below. Same radio-row + checkmark visual as
    // AudioSection.qml's output list, parameterized for reuse.
    component OutputChoice: CyberRect {
        id: choice
        required property string label
        required property bool active
        signal chosen()
        width: parent.width
        height: 30
        radius: Theme.radiusSm
        color: active ? Theme.alpha(Theme.accent, 0.18)
                      : Theme.alpha(Theme.current.hover, choiceMa.containsMouse ? 0.6 : 0.4)
        border.width: 1
        border.color: active ? Theme.alpha(Theme.accent, 0.6) : Theme.strokeGlass
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: choice.label
                color: Theme.text
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
                width: parent.width - 22
            }
            IconGlyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: choice.active
                name: "check"; size: 14; color: Theme.accent
            }
        }
        MouseArea {
            id: choiceMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.chosen()
        }
    }

    // ------------------------------------------------------------ header
    // Tab-aware: the Outputs tab controls the default sink, the Inputs tab
    // the default source. This is the only slider for whichever device is
    // active default -- its own card in the list below hides its slider
    // (see `!card.isDefault`) on the assumption this header covers it, so it
    // has to actually track the active tab's device rather than always the
    // sink.
    readonly property bool headerIsSource: tab === "in"
    readonly property var headerNode: headerIsSource ? Audio.source : Audio.sink
    readonly property string headerName: headerIsSource ? Audio.sourceName : Audio.deviceName
    readonly property real headerVolume: headerIsSource ? Audio.sourceVolume : Audio.volume
    readonly property bool headerMuted: headerIsSource ? Audio.sourceMuted : Audio.muted

    Row {
        width: parent.width
        spacing: 16
        visible: root.tab !== "streams"

        // device-type tile
        CyberRect {
            width: 104; height: 104; radius: Theme.radius
            color: Theme.alpha(Theme.subtext, 0.8)
            border.width: 1; border.color: Theme.strokeGlass
            IconGlyph {
                anchors.centerIn: parent
                name: root._audioIcon(root.headerNode)
                size: 48
                color: Theme.accent
            }
        }

        // device name + node id + main volume row
        Column {
            width: parent.width - 104 - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                width: parent.width
                text: root.headerName !== "" ? root.headerName : (root.headerIsSource ? "No input" : "No output")
                color: Theme.text
                font.pixelSize: Theme.fontSize + 3
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.headerNode ? root.headerNode.name : ""
                visible: text !== ""
                color: Theme.subtext
                font.family: "monospace"
                font.pixelSize: Theme.fontSize - 3
                elide: Text.ElideRight
            }
            Row {
                width: parent.width
                spacing: 10
                IconGlyph {
                    id: muteIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.headerMuted ? "volumeMute" : "volume"; size: 18
                    color: Theme.text
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.headerIsSource ? Audio.toggleSourceMute() : Audio.toggleMute()
                    }
                }
                MiniSlider {
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.headerVolume
                    onMoved: (v) => root.headerIsSource ? Audio.setSourceVolume(v) : Audio.setVolume(v)
                }
            }
        }
    }

    // ------------------------------------------------------------ tabs
    CyberRect {
        width: parent.width; height: 40; radius: height / 2
        color: Theme.alpha(Theme.current.hover, 0.5)
        border.width: 1; border.color: Theme.strokeGlass
        Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4
            Repeater {
                id: tabsRep
                model: [
                    { id: "out", label: "Outputs" },
                    { id: "in", label: "Inputs" },
                    { id: "streams", label: "Streams" }
                ]
                delegate: CyberRect {
                    required property var modelData
                    readonly property bool on: root.tab === modelData.id
                    width: (parent.width - 8) / 3
                    height: parent.height
                    radius: height / 2
                    color: on ? Theme.alpha(Theme.accent, 0.92)
                              : (tabMa.containsMouse ? Theme.alpha(Theme.current.hover, 0.6) : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.on ? Theme.current.onAccent : Theme.text
                        font.pixelSize: Theme.fontSize - 1
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = modelData.id
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ device list
    readonly property var list: {
        var src = tab === "out" ? Audio.sinks : tab === "in" ? Audio.sources : Audio.streams
        var f = (filter || "").toLowerCase().trim()
        if (f === "") return src
        var out = []
        for (var i = 0; i < src.length; i++) {
            var nd = src[i]
            var nm = ((nd.description || nd.nickname || nd.name || "") + " " + (nd.name || "")).toLowerCase()
            if (nm.indexOf(f) >= 0) out.push(nd)
        }
        return out
    }

    Text {
        width: parent.width
        visible: root.list.length === 0
        text: root.tab === "out" ? "No output devices"
            : root.tab === "in" ? "No input devices"
            : "Nothing is playing"
        color: Theme.subtext
        font.pixelSize: Theme.fontSize - 1
    }

    Column {
        width: parent.width
        spacing: 10
        Repeater {
            id: devicesRep
            model: root.list
            delegate: CyberRect {
                id: card
                required property var modelData
                readonly property bool isDefault: root.tab === "out"
                    ? (Audio.sink && modelData.id === Audio.sink.id)
                    : root.tab === "in"
                        ? (Audio.source && modelData.id === Audio.source.id)
                        : false
                readonly property bool selectable: root.tab !== "streams"
                readonly property string title:
                    modelData.description || modelData.nickname || modelData.name || "Device"

                // ---- per-stream output routing (Streams tab only) ----
                property bool pickerOpen: false
                property alias outputToggleItem: outputToggleRow
                property alias followChoice: followChoiceItem
                property alias outputChoicesRepeater: outputChoicesRep
                PwNodeLinkTracker {
                    id: linkTracker
                    node: root.tab === "streams" ? card.modelData : null
                }
                readonly property var currentTarget: linkTracker.linkGroups.length > 0
                    ? linkTracker.linkGroups[0].target : null
                readonly property string currentTargetName: card.currentTarget
                    ? (card.currentTarget.description || card.currentTarget.nickname || card.currentTarget.name || "Output")
                    : "Default"

                width: parent.width
                radius: Theme.radiusSm + 2
                implicitHeight: col.implicitHeight + 24
                color: isDefault ? Theme.alpha(Theme.accent, 0.9)
                    : Theme.alpha(Theme.current.hover, (cardMa.containsMouse && selectable && !isDefault) ? 0.62 : 0.42)
                border.width: 1
                border.color: isDefault ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: card.selectable && !card.isDefault
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab === "out" ? Audio.setSink(card.modelData)
                                                  : Audio.setSource(card.modelData)
                }

                Column {
                    id: col
                    x: 14; y: 12
                    width: parent.width - 28
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 12
                        CyberRect {
                            width: 34; height: 34; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: card.isDefault ? Theme.alpha(Theme.current.onAccent, 0.18)
                                                  : Theme.alpha(Theme.accent, 0.16)
                            IconGlyph {
                                anchors.centerIn: parent
                                name: root.tab === "in" ? "brightness" : "volume"
                                size: 17
                                color: card.isDefault ? Theme.current.onAccent : Theme.text
                            }
                        }
                        Column {
                            width: parent.width - 34 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: card.title
                                color: card.isDefault ? Theme.current.onAccent : Theme.text
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: card.isDefault ? "Active default" : (card.modelData.name || "")
                                color: card.isDefault ? Theme.alpha(Theme.current.onAccent, 0.8) : Theme.subtext
                                font.family: card.isDefault ? "sans-serif" : "monospace"
                                font.pixelSize: Theme.fontSize - 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // per-device volume (hidden on the active-default card — the
                    // big header tile already controls that one)
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: !card.isDefault
                        IconGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: (card.modelData.audio && card.modelData.audio.muted) ? "volumeMute" : "volume"
                            size: 16; color: Theme.text
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.toggleNodeMute(card.modelData)
                            }
                        }
                        MiniSlider {
                            width: parent.width - 26
                            anchors.verticalCenter: parent.verticalCenter
                            value: card.modelData.audio ? card.modelData.audio.volume : 0
                            onMoved: (v) => Audio.setNodeVolume(card.modelData, v)
                        }
                    }

                    // per-stream output picker: which device this one app's
                    // audio plays through, independent of the system default
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: root.tab === "streams"

                        Item {
                            id: outputToggleRow
                            width: parent.width
                            height: 22
                            Row {
                                anchors.fill: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Output: " + card.currentTargetName
                                    color: Theme.subtext
                                    font.pixelSize: Theme.fontSize - 3
                                    elide: Text.ElideRight
                                    width: parent.width - 18
                                }
                                IconGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "chevron"; size: 12; color: Theme.subtext
                                    rotation: card.pickerOpen ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: Theme.animFast } }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.pickerOpen = !card.pickerOpen
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: card.pickerOpen

                            OutputChoice {
                                id: followChoiceItem
                                label: "Follow default output"
                                active: !card.currentTarget
                                onChosen: {
                                    Audio.clearStreamOutput(card.modelData)
                                    card.pickerOpen = false
                                }
                            }
                            Repeater {
                                id: outputChoicesRep
                                model: Audio.sinks
                                delegate: OutputChoice {
                                    required property var modelData
                                    label: modelData.description || modelData.nickname || modelData.name || "Output"
                                    active: !!(card.currentTarget && card.currentTarget.id === modelData.id)
                                    onChosen: {
                                        Audio.setStreamOutput(card.modelData, modelData)
                                        card.pickerOpen = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
