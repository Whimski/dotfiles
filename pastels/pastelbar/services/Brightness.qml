pragma Singleton
import QtQuick
import Quickshell.Io

// Backlight via `brightnessctl` (no native module). Follows pastelfm's
// MountManager pattern: spawn the CLI, parse output, expose state, degrade
// gracefully. `brightnessctl -m` prints: device,class,current,percent,max.
QtObject {
    id: br

    property real value: 1.0        // 0..1
    property bool available: true
    property int _max: 0

    property Process _get: Process {
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            id: coll
            onStreamFinished: br._parse(coll.text)
        }
        onExited: (code) => { if (code !== 0) br.available = false }
    }

    property Process _set: Process {
        onExited: br.refresh()
    }

    Component.onCompleted: refresh()

    function refresh() { _get.running = true }

    function _parse(t) {
        var line = (t || "").trim().split("\n")[0]
        if (!line) return
        var f = line.split(",")
        if (f.length >= 5) {
            br._max = parseInt(f[4])
            var cur = parseInt(f[2])
            if (br._max > 0) br.value = cur / br._max
            br.available = true
        }
    }

    function setValue(v) {
        v = Math.max(0.01, Math.min(1, v))
        value = v
        _set.command = ["brightnessctl", "set", Math.round(v * 100) + "%"]
        _set.running = true
    }
}
