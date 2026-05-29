pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One niri IPC connection for the whole shell.
// The event-stream is used only as a "something changed" trigger; on any
// line we re-read the authoritative snapshot. Resilient to event-shape
// changes and instant (this is what kills the old Python language lag).
Singleton {
    id: root

    // [{ idx, urgent, empty }] sorted by idx. Reassigned ONLY when the set
    // actually changes (dedupe) so delegates don't rebuild on every event.
    property var workspaces: []
    // active workspace idx — cheap int, updates every refresh, drives blink.
    property int activeWs: -1
    property string layoutShort: ""
    property string _wsCache: ""

    function refresh() {
        wsProc.running = true;
        klProc.running = true;
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => root.refresh()
        }
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text);
                    arr.sort((a, b) => a.idx - b.idx);
                    var list = arr.map(w => ({
                        idx: w.idx,
                        urgent: w.is_urgent,
                        empty: w.active_window_id === null
                    }));
                    var key = JSON.stringify(list);
                    if (key !== root._wsCache) {
                        root._wsCache = key;
                        root.workspaces = list;   // rebuild only on real change
                    }
                    var a = arr.find(w => w.is_active);
                    root.activeWs = a ? a.idx : -1;
                } catch (e) {}
            }
        }
    }

    Process {
        id: klProc
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var k = JSON.parse(text);
                    var n = k.names[k.current_idx] || "";
                    root.layoutShort = n.slice(0, 2).toUpperCase();
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: refresh()
}
