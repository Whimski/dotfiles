import QtQuick
import ".."

// Vimium-style "hint mode": call start(list) with the same {key, item, activate}
// shape produced by a panel's _kbList(), and it drops a lettered badge on every
// entry that has both an `item` (for a screen position) and an `activate` (something
// to actually do — sliders with only incr/decr aren't "clickable" so they're skipped,
// same as Vimium doesn't hint scrollbars). Typing a label's letters — no Enter needed
// — fires that entry's activate() and exits hint mode; Escape/Backspace edit the typed
// prefix. Labels are generated prefix-free (Vimium's own algorithm: BFS over `chars`,
// keeping only the leaves) so no label is ever a prefix of another one on screen.
Item {
    id: root
    z: 999
    visible: active

    property bool active: false
    property string typed: ""
    property var entries: []
    // Coordinate space to resolve each entry.item's position into — pass the same
    // Flickable.contentItem the entries' items actually live in, so badges land in
    // the right spot and scroll/clip with the content.
    property Item mapTo: root
    // Optional {y, height} window (in mapTo's coordinate space) — entries outside
    // it are dropped, mirroring Vimium only hinting what's actually in view.
    property var viewport: null

    readonly property string chars: "asdfghjkl"

    // An entry may also carry `clipTo` (an Item, e.g. a Flickable) — it's dropped
    // when it lies vertically outside that item's rect. Lets one overlay span
    // several surfaces, only some of which scroll.
    function start(list) {
        var picked = []
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e.activate || !e.item || e.item.width <= 0 || e.item.height <= 0) continue
            var p = e.item.mapToItem(root.mapTo, 0, 0)
            if (root.viewport && (p.y + e.item.height < root.viewport.y || p.y > root.viewport.y + root.viewport.height)) continue
            if (e.clipTo) {
                var c = e.clipTo.mapToItem(root.mapTo, 0, 0)
                if (p.y + e.item.height < c.y || p.y > c.y + e.clipTo.height) continue
            }
            picked.push({ item: e.item, activate: e.activate, x: p.x, y: p.y, w: e.item.width, h: e.item.height })
        }
        var labels = _labels(picked.length)
        for (var j = 0; j < picked.length; j++) picked[j].label = labels[j]
        root.entries = picked
        root.typed = ""
        root.active = picked.length > 0
    }

    function cancel() { active = false; typed = ""; entries = [] }

    // Re-maps every current entry's on-screen position without touching labels
    // or the typed prefix — for callers whose targets keep moving (e.g. an
    // orbiting layout) so badges track their target instead of the widget
    // needing to freeze in place for the duration of hint mode.
    function reposition() {
        if (!active) return
        var updated = []
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            var p = e.item.mapToItem(root.mapTo, 0, 0)
            updated.push({ item: e.item, activate: e.activate, label: e.label, x: p.x, y: p.y, w: e.item.width, h: e.item.height })
        }
        root.entries = updated
    }

    // Returns true if the key was consumed (caller should stop further handling).
    function handleKey(event) {
        if (!active) return false
        if (event.key === Qt.Key_Escape) { cancel(); return true }
        if (event.key === Qt.Key_Backspace) { typed = typed.slice(0, -1); return true }
        var ch = (event.text || "").toLowerCase()
        if (ch.length !== 1 || chars.indexOf(ch) < 0) return true
        var next = typed + ch
        var matches = entries.filter((e) => e.label.indexOf(next) === 0)
        if (matches.length === 0) return true
        typed = next
        if (matches.length === 1 && matches[0].label === typed) {
            var act = matches[0].activate
            cancel()
            act()
        }
        return true
    }

    // Vimium's hint-label algorithm: BFS-generate strings over `chars`, then keep
    // only the leaves still in the queue — guarantees the result is prefix-free.
    // Must APPEND the new character (not prepend): appending means every string
    // starts with its root-level character, so an unexpanded short leaf (e.g. "d")
    // can never collide as a string-prefix of a deeper leaf from a different
    // branch (e.g. "af").
    function _labels(count) {
        if (count <= 0) return []
        var pool = chars.split("")
        var hints = [""]
        var offset = 0
        while (hints.length - offset < count || hints.length === 1) {
            var hint = hints[offset++]
            for (var i = 0; i < pool.length; i++) hints.push(hint + pool[i])
        }
        return hints.slice(offset, offset + count).sort()
    }

    Repeater {
        model: root.entries
        delegate: Rectangle {
            required property var modelData
            x: modelData.x - 3
            y: modelData.y - 3
            width: label.implicitWidth + 8
            height: label.implicitHeight + 3
            radius: 4
            color: Theme.accent
            opacity: modelData.label.indexOf(root.typed) === 0 ? 1 : 0.25
            Text {
                id: label
                anchors.centerIn: parent
                text: modelData.label.toUpperCase()
                font.pixelSize: 11
                font.bold: true
                font.family: "monospace"
                color: Theme.current.onAccent
            }
        }
    }
}
