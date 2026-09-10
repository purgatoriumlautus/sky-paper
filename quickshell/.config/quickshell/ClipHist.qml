pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard-history backend. The store belongs to cliphist, fed by the
// `wl-paste --type text --watch cliphist store` niri spawns at startup —
// so nothing resident lives here: the list is read once per open and the
// two actions are detached one-shots. View layer is ClipPicker.qml.
Singleton {
    id: root

    // current search text, driven by the input in ClipPicker.qml
    property string query: ""

    // history, newest first — the order cliphist already prints.
    // row: { id, label, line }. `cliphist list` prints "<id>\t<preview>";
    // `cliphist delete` wants that whole line back on stdin.
    property var entries: []
    property var results: []

    onQueryChanged: results = filter()

    // Substring, NOT the launcher's fuzzy scorer: clipboard rows are long
    // free text, where a subsequence matches nearly everything and the
    // ranking stops carrying information. Plain contains also leaves the
    // list in recency order, which is the order that matters here.
    function filter() {
        var q = root.query.trim().toLowerCase();
        if (q.length === 0) return root.entries;
        var out = [];
        for (var i = 0; i < root.entries.length; i++)
            if (root.entries[i].label.toLowerCase().indexOf(q) !== -1)
                out.push(root.entries[i]);
        return out;
    }

    // one process per open, nothing between opens
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab <= 0) continue;    // blank tail line / malformed
                    out.push({ id:    lines[i].slice(0, tab),
                               label: lines[i].slice(tab + 1),
                               line:  lines[i] });
                }
                // newest first. cliphist already prints them that way; the
                // sort makes the order the picker's own property rather than
                // a habit of whatever cliphist version is installed. ids grow
                // monotonically, so descending id IS most-recent-first.
                out.sort(function (a, b) { return Number(b.id) - Number(a.id); });
                root.entries = out;
                root.results = root.filter();
            }
        }
    }
    function reload() { listProc.running = true; }

    // Both actions go through `sh -c '… "$1"' sh <data>`: the row reaches the
    // script as an ARGUMENT, never spliced into it, so a clipboard entry full
    // of quotes, tabs or newlines cannot break out. execDetached because
    // neither has output worth collecting or a lifetime worth managing —
    // a Process object would only add state to keep in sync.
    function copy(row) {
        if (!row) return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", row.id]);
    }

    function remove(row) {
        if (!row) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", row.line]);
        // drop it here too instead of re-listing: the picker stays open, the
        // row disappears on the keypress, and cliphist's store is the only
        // other copy of the truth — which the next open re-reads anyway.
        var e = root.entries.slice();
        for (var i = 0; i < e.length; i++)
            if (e[i].id === row.id) { e.splice(i, 1); break; }
        root.entries = e;
        root.results = filter();
    }
}
