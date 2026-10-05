import QtQuick
import ".."

// A block of "data noise" after the DATA row of
// docs/cyberpunk-refs/data-buttons-dividers.jpg: `rows` lines of random-width
// dashes that reshuffle a few rows at a time while `running`, so it reads as
// streaming data. Purely decorative.
Item {
    id: dn
    property int rows: 6
    property color color: Theme.accent
    property bool running: true
    property int interval: 140
    readonly property real rowH: 3
    readonly property real gap: 2

    implicitWidth: 140
    implicitHeight: rows * (rowH + gap)

    // one list of [x, w] fractions per row
    property var data: []
    function _row() {
        const out = []
        let x = Math.random() * 0.1
        while (x < 0.98) {
            const w = Math.min(0.98 - x, 0.02 + Math.random() * (Math.random() < 0.2 ? 0.3 : 0.08))
            if (Math.random() < 0.8) out.push([x, w])
            x += w + 0.01 + Math.random() * 0.05
        }
        return out
    }
    function _shuffle(n) {
        const d = data.length === rows ? data.slice() : Array.from({ length: rows }, () => _row())
        for (let i = 0; i < n; i++) d[Math.floor(Math.random() * rows)] = _row()
        data = d
    }
    Component.onCompleted: _shuffle(rows)
    Timer {
        running: dn.running && dn.visible
        interval: dn.interval; repeat: true
        onTriggered: dn._shuffle(2)
    }

    Repeater {
        model: dn.rows
        Item {
            id: row
            required property int index
            y: index * (dn.rowH + dn.gap)
            width: dn.width; height: dn.rowH
            Repeater {
                model: dn.data[row.index] || []
                Rectangle {
                    required property var modelData
                    x: dn.width * modelData[0]
                    width: Math.max(1, dn.width * modelData[1]); height: dn.rowH
                    color: dn.color
                    opacity: modelData[1] > 0.15 ? 0.45 : 0.85
                }
            }
        }
    }
}
