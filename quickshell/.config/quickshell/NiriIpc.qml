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

    // [{ idx, output, urgent, empty }] sorted by (output, idx). Reassigned
    // ONLY when the set actually changes (dedupe) so delegates don't rebuild
    // on every event. NOTE: per-output "active" is deliberately NOT in here —
    // it lives in activeByOutput so a workspace switch updates the highlight
    // without rebuilding the strip.
    property var workspaces: []
    // { "DP-3": idx, "DP-2": idx } — each output's currently-shown workspace.
    // Cheap object, reassigned every refresh; drives per-monitor highlight.
    property var activeByOutput: ({})
    // output name of the globally focused workspace (the monitor the user is
    // on). Routes the control-center / launcher popups to the right bar.
    property string focusedOutput: ""
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
                    arr.sort((a, b) => a.output === b.output
                        ? a.idx - b.idx
                        : (a.output < b.output ? -1 : 1));
                    var list = arr.map(w => ({
                        idx: w.idx,
                        output: w.output,
                        urgent: w.is_urgent,
                        empty: w.active_window_id === null
                    }));
                    var key = JSON.stringify(list);
                    if (key !== root._wsCache) {
                        root._wsCache = key;
                        root.workspaces = list;   // rebuild only on real change
                    }
                    // per-output active idx + focused output — cheap, every refresh
                    var act = {};
                    for (var i = 0; i < arr.length; i++)
                        if (arr[i].is_active) act[arr[i].output] = arr[i].idx;
                    root.activeByOutput = act;
                    var f = arr.find(w => w.is_focused);
                    root.focusedOutput = f ? f.output : "";
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
