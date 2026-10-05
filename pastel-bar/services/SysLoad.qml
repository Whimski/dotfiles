pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// CPU and memory load for the cyberpunk pill's HUD gauges. Samples /proc/stat
// and /proc/meminfo once a second, only while cyberpunk mode is on (the
// steampunk clockwork reads /proc/stat itself). `cpuHist` / `memHist` keep the
// last `histLen` samples (oldest first) for the readouts' bar graphs.
Singleton {
    id: root
    property real cpu: 0          // 0..1
    property real mem: 0          // 0..1, (total - available) / total
    property var cpuHist: []
    property var memHist: []
    readonly property int histLen: 14

    property var _prev: null
    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }

    function _push(arr, v) {
        const a = arr.slice(-(histLen - 1))
        a.push(v)
        return a
    }
    function _sample() {
        stat.reload()
        const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
        const idle = f[3] + (f[4] || 0)
        const total = f.reduce((s, v) => s + v, 0)
        if (_prev && total > _prev.total)
            cpu = Math.max(0, Math.min(1, 1 - (idle - _prev.idle) / (total - _prev.total)))
        _prev = { idle: idle, total: total }

        meminfo.reload()
        const t = meminfo.text()
        const kb = k => { const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")); return m ? Number(m[1]) : 0 }
        const tot = kb("MemTotal"), avail = kb("MemAvailable")
        if (tot > 0) mem = Math.max(0, Math.min(1, (tot - avail) / tot))

        // reassigned wholesale so bindings on the arrays re-evaluate
        cpuHist = _push(cpuHist, cpu)
        memHist = _push(memHist, mem)
    }
    Timer {
        running: Theme.cyberpunk
        interval: 1000; repeat: true; triggeredOnStart: true
        onTriggered: root._sample()
    }
}
