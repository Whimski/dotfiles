import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import PastelCal
import pasteltheme

// Create / edit / delete an event. Writes go through the Google Calendar API
// (Google is the only writable source); read-only (ICS) events open disabled.
Popup {
    id: root
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 400
    padding: 20
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string mode: "new"          // "new" | "edit"
    property string editId: ""
    property string calId: ""
    property string fTitle: ""
    property string fDate: ""            // yyyy-MM-dd
    property bool   fAllDay: false
    property string fStart: "09:00"
    property string fEnd: "10:00"
    property string fRepeat: ""          // "" | "FREQ=DAILY" | WEEKLY | MONTHLY | YEARLY
    // Recurrence (edit mode): whether this event is part of a series, its master id,
    // and whether the user chose to apply changes to the whole series.
    property bool   fRecurring: false
    property string fMasterId: ""
    property bool   fScopeAll: false

    function _pad(n) { return (n < 10 ? "0" : "") + n }
    function _isoDate(d) { return d.getFullYear() + "-" + _pad(d.getMonth() + 1) + "-" + _pad(d.getDate()) }
    function _firstWritable() {
        var cs = Cal.calendars
        for (var i = 0; i < cs.length; i++) if (cs[i].writable) return cs[i].id
        return ""
    }
    function _isWritable(id) {
        var cs = Cal.calendars
        for (var i = 0; i < cs.length; i++) if (cs[i].id === id) return cs[i].writable === true
        return false
    }
    readonly property bool calWritable: _isWritable(calId)

    function openNew(iso) {
        mode = "new"; editId = ""
        var d = iso ? new Date(iso) : new Date()
        var h = (new Date().getHours() + 1) % 24
        fTitle = ""; fDate = _isoDate(d); fAllDay = false
        fStart = _pad(h) + ":00"; fEnd = _pad((h + 1) % 24) + ":00"
        fRepeat = ""; fRecurring = false; fMasterId = ""; fScopeAll = false
        calId = _firstWritable()
        open()
    }
    function openEdit(ev) {
        mode = "edit"; editId = ev.id; calId = ev.calendarId
        fTitle = ev.title; fAllDay = ev.allDay === true
        var s = ev.start, e = ev.end
        fDate = _isoDate(s)
        fStart = _pad(s.getHours()) + ":" + _pad(s.getMinutes())
        fEnd = _pad(e.getHours()) + ":" + _pad(e.getMinutes())
        fRepeat = ""
        fRecurring = ev.recurring === true
        fMasterId = ev.recurringEventId || ev.id
        fScopeAll = false
        open()
    }
    function _save() {
        var startIso, endIso
        if (fAllDay) {
            startIso = fDate
            var d = new Date(fDate); d.setDate(d.getDate() + 1); endIso = _isoDate(d)
        } else {
            startIso = fDate + "T" + fStart + ":00"
            endIso = fDate + "T" + fEnd + ":00"
        }
        if (mode === "new") {
            Google.createEvent(calId, fTitle, startIso, endIso, fAllDay, fRepeat)
        } else if (fRecurring && fScopeAll) {
            Google.updateSeries(calId, fMasterId, fTitle, startIso, endIso, fAllDay)
        } else {
            Google.updateEvent(calId, editId, fTitle, startIso, endIso, fAllDay)
        }
        close()
    }
    function _delete() {
        // "All events" deletes the master (whole series); otherwise this occurrence.
        Google.deleteEvent(calId, (fRecurring && fScopeAll) ? fMasterId : editId)
        close()
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.glassBg
        border.color: Theme.alpha(Theme.glow, 0.5)
        border.width: 1
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        signal picked()
        height: 28; width: chipText.implicitWidth + 20
        radius: Theme.radiusSm
        color: chip.selected ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.5)
        border.width: 1; border.color: Theme.strokeGlass
        Text {
            id: chipText; anchors.centerIn: parent; text: chip.label
            color: chip.selected ? Theme.current.onAccent : Theme.current.text; font.pixelSize: 12
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.picked() }
    }

    component F: TextField {
        color: Theme.current.text
        placeholderTextColor: Theme.current.subtext
        font.pixelSize: 13
        selectByMouse: true
        leftPadding: 10; rightPadding: 10; topPadding: 7; bottomPadding: 7
        background: Rectangle {
            radius: Theme.radiusSm
            color: Theme.alpha(Theme.current.panel, Theme.glassOpacity)
            border.width: 1
            border.color: parent.activeFocus ? Theme.alpha(Theme.accent, 0.7) : Theme.strokeGlass
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: root.mode === "edit" ? "Edit event" : "New event"
            color: Theme.current.text; font.pixelSize: 18; font.weight: Font.DemiBold
        }

        // read-only notice (no writable calendar / ICS event)
        Text {
            Layout.fillWidth: true
            visible: root.calId === "" || !root.calWritable
            text: root.calId === "" ? "No writable calendar. Connect a Google account (Settings) to add events."
                                    : "This calendar is read-only."
            color: Theme.current.subtext; font.pixelSize: 12; wrapMode: Text.Wrap
        }

        F {
            id: titleField
            Layout.fillWidth: true
            placeholderText: "Title"
            text: root.fTitle
            enabled: root.calWritable
            onTextChanged: root.fTitle = text
        }

        // calendar picker (new event, writable calendars only)
        Flow {
            Layout.fillWidth: true
            visible: root.mode === "new" && root.calWritable
            spacing: 6
            Repeater {
                model: Cal.calendars
                delegate: Rectangle {
                    required property var modelData
                    visible: modelData.writable === true
                    height: 28; width: pickRow.implicitWidth + 18
                    radius: Theme.radiusSm
                    color: root.calId === modelData.id ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.5)
                    border.width: 1; border.color: Theme.strokeGlass
                    Row {
                        id: pickRow; anchors.centerIn: parent; spacing: 6
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: modelData.color }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.summary
                               color: root.calId === modelData.id ? Theme.current.onAccent : Theme.current.text; font.pixelSize: 12 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.calId = modelData.id }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "Date"; color: Theme.current.text; font.pixelSize: 13 }
            F { Layout.fillWidth: true; placeholderText: "yyyy-MM-dd"; text: root.fDate; enabled: root.calWritable; onTextChanged: root.fDate = text }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "All day"; color: Theme.current.text; font.pixelSize: 13; Layout.fillWidth: true }
            Rectangle {
                width: 44; height: 24; radius: 12
                color: root.fAllDay ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.current.hover, 0.6)
                border.width: 1; border.color: Theme.strokeGlass
                Rectangle { width: 18; height: 18; radius: 9; color: Theme.dark ? "#e9e9ef" : "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter; x: root.fAllDay ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } } }
                MouseArea { anchors.fill: parent; enabled: root.calWritable; cursorShape: Qt.PointingHandCursor; onClicked: root.fAllDay = !root.fAllDay }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !root.fAllDay
            spacing: 10
            Text { text: "Time"; color: Theme.current.text; font.pixelSize: 13 }
            F { Layout.preferredWidth: 80; placeholderText: "HH:mm"; text: root.fStart; enabled: root.calWritable; onTextChanged: root.fStart = text }
            Text { text: "→"; color: Theme.current.subtext; font.pixelSize: 13 }
            F { Layout.preferredWidth: 80; placeholderText: "HH:mm"; text: root.fEnd; enabled: root.calWritable; onTextChanged: root.fEnd = text }
            Item { Layout.fillWidth: true }
        }

        // Repeat picker (new events). Sets the RRULE frequency.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.mode === "new" && root.calWritable
            Text { text: "Repeat"; color: Theme.current.text; font.pixelSize: 13 }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [["No repeat", ""], ["Daily", "FREQ=DAILY"], ["Weekly", "FREQ=WEEKLY"],
                            ["Monthly", "FREQ=MONTHLY"], ["Yearly", "FREQ=YEARLY"]]
                    delegate: Chip {
                        required property var modelData
                        label: modelData[0]
                        selected: root.fRepeat === modelData[1]
                        onPicked: root.fRepeat = modelData[1]
                    }
                }
            }
        }

        // Edit scope for recurring events: this occurrence vs the whole series.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.mode === "edit" && root.fRecurring && root.calWritable
            Text { text: "Apply to"; color: Theme.current.text; font.pixelSize: 13 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Chip { label: "This event"; selected: !root.fScopeAll; onPicked: root.fScopeAll = false }
                Chip { label: "All events"; selected: root.fScopeAll;  onPicked: root.fScopeAll = true }
                Item { Layout.fillWidth: true }
            }
            Text {
                Layout.fillWidth: true
                visible: root.fScopeAll
                text: "Changes apply to every occurrence (the series keeps its own start date)."
                color: Theme.current.subtext; font.pixelSize: 11; wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.topMargin: 4
            Layout.fillWidth: true
            spacing: 8
            // Delete (edit mode)
            Rectangle {
                visible: root.mode === "edit" && root.calWritable
                Layout.preferredHeight: 32; Layout.preferredWidth: (root.fRecurring && root.fScopeAll) ? 92 : 76; radius: Theme.radiusSm
                color: delMa.containsMouse ? Theme.alpha(Theme.current.danger, 0.9) : Theme.alpha(Theme.current.danger, 0.15)
                border.width: 1; border.color: Theme.alpha(Theme.current.danger, 0.6)
                Text { anchors.centerIn: parent
                       text: (root.fRecurring && root.fScopeAll) ? "Delete all" : "Delete"
                       color: delMa.containsMouse ? "#ffffff" : Theme.current.danger; font.pixelSize: 13 }
                MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root._delete() }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 32; Layout.preferredWidth: 74; radius: Theme.radiusSm
                color: cxMa.containsMouse ? Theme.current.hover : "transparent"
                border.width: 1; border.color: Theme.strokeGlass
                Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.current.text; font.pixelSize: 13 }
                MouseArea { id: cxMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
            Rectangle {
                Layout.preferredHeight: 32; Layout.preferredWidth: 74; radius: Theme.radiusSm
                enabled: root.calWritable && root.fTitle.trim() !== ""
                opacity: enabled ? 1 : 0.4
                color: saveMa.containsMouse ? Theme.alpha(Theme.accent, 0.9) : Theme.alpha(Theme.accent, 0.78)
                Text { anchors.centerIn: parent; text: "Save"; color: Theme.current.onAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; enabled: parent.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root._save() }
            }
        }
    }
}
