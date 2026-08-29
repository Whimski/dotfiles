pragma Singleton
import QtQuick
import Quickshell.Io

// Night light via `wlsunset` (no native module). While enabled, run wlsunset at a
// fixed warm temperature; disabling terminates it. State is transient (defaults
// off) — persist in Settings later if wanted.
QtObject {
    id: nl

    property bool enabled: false
    property int temperature: 4000

    property Process _proc: Process {
        running: nl.enabled
        command: ["wlsunset", "-T", String(nl.temperature), "-t", String(nl.temperature)]
    }

    function toggle() { enabled = !enabled }
    function setEnabled(b) { enabled = b }
}
