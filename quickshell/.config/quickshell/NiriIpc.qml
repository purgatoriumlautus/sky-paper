pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One niri IPC connection for the whole shell.
//
// The event-stream is dispatched BY EVENT TYPE. It used to be treated as a bare
// "something changed" bell: every single line re-forked two `niri msg` processes
// to re-read the authoritative snapshot. That cost two processes per event —
// including every WindowFocusChanged, i.e. every hjkl move between windows.
// Measured: six IPC actions (2 workspace switches, 2 layout switches, 2 column
// focus moves) produced 17 events = 34 forks.
//
// niri's payloads already carry what this file needs, so most cases now cost
// nothing:
//   WorkspacesChanged        full snapshot  -> applied directly
//   KeyboardLayoutsChanged   {names, current_idx} -> applied directly
//   KeyboardLayoutSwitched   {idx}          -> resolved against cached names
//   WorkspaceActivated       {id, focused}  -> resolved against cached id->idx
//
// Two workspace deltas still re-read the snapshot, deliberately: their payload
// field names are NOT verified here (they were not observed in the captured
// stream), and guessing them would fail silently. One fork is the honest price
// for that, and they are rare (urgency; last window of a workspace closing).
//
// Anything unknown falls through to a full refresh, so a future niri that adds
// an event type degrades to the old behaviour instead of going stale.
Singleton {
    id: root

    // ---- public interface (unchanged) -------------------------------------
    // [{ idx, urgent, empty }] sorted by idx. Reassigned ONLY when the set
    // actually changes (dedupe) so delegates don't rebuild on every event.
    property var workspaces: []
    // active workspace idx — cheap int, drives the highlight in Workspaces.qml.
    property int activeWs: -1
    // two-letter layout tag; Language.qml blinks on its change.
    property string layoutShort: ""

    // ---- internal state ---------------------------------------------------
    property string _wsCache: ""       // dedupe key for `workspaces`
    property var    _wsRaw: []         // raw payload, kept for the id -> idx map
    property var    _layoutNames: []   // cached names for KeyboardLayoutSwitched

    // Events that cannot affect anything above. Listed explicitly rather than
    // handled by a catch-all `return`, so that an unlisted (future) event still
    // triggers the conservative refresh below.
    readonly property var _ignored: ({
        "WindowsChanged": 1,
        "WindowOpenedOrChanged": 1,
        "WindowClosed": 1,
        "WindowFocusChanged": 1,
        "WindowFocusTimestampChanged": 1,
        "WindowLayoutsChanged": 1,
        "WindowUrgencyChanged": 1,
        "OverviewOpenedOrClosed": 1,
        "OutputConfigChanged": 1,
        "ConfigLoaded": 1,
        "CastsChanged": 1
    })

    function refresh() {
        wsProc.running = true;
        klProc.running = true;
    }

    // ---- payload appliers, shared by the stream and by the msg fallbacks ---
    function applyWorkspaces(arr) {
        var sorted = arr.slice().sort((a, b) => a.idx - b.idx);
        root._wsRaw = sorted;
        var list = sorted.map(w => ({
            idx: w.idx,
            urgent: w.is_urgent,
            empty: w.active_window_id === null
        }));
        var key = JSON.stringify(list);
        if (key !== root._wsCache) {
            root._wsCache = key;
            root.workspaces = list;   // rebuild only on real change
        }
        var a = sorted.find(w => w.is_active);
        root.activeWs = a ? a.idx : -1;
    }

    function applyLayouts(kl) {
        root._layoutNames = kl.names || [];
        var n = root._layoutNames[kl.current_idx] || "";
        root.layoutShort = n.slice(0, 2).toUpperCase();
    }

    // ---- event dispatch ---------------------------------------------------
    function onEvent(line) {
        var ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;                       // partial / non-JSON line: ignore
        }
        var keys = Object.keys(ev);
        if (keys.length === 0) return;
        var key = keys[0];

        switch (key) {

        case "WorkspacesChanged":
            applyWorkspaces(ev[key].workspaces || []);
            return;

        case "KeyboardLayoutsChanged":
            applyLayouts(ev[key].keyboard_layouts || {});
            return;

        case "KeyboardLayoutSwitched": {
            var n = root._layoutNames[ev[key].idx];
            if (n === undefined) { klProc.running = true; return; }  // no names yet
            root.layoutShort = n.slice(0, 2).toUpperCase();
            return;
        }

        case "WorkspaceActivated": {
            var raw = root._wsRaw;
            var newIdx = -1;
            for (var i = 0; i < raw.length; i++) {
                raw[i].is_active = (raw[i].id === ev[key].id);
                if (raw[i].is_active) newIdx = raw[i].idx;
            }
            if (newIdx < 0) { wsProc.running = true; return; }       // cache stale
            root._wsRaw = raw;
            root.activeWs = newIdx;
            return;
        }

        // Payload field names unverified — re-read the snapshot (1 fork, rare).
        case "WorkspaceUrgencyChanged":
        case "WorkspaceActiveWindowChanged":
            wsProc.running = true;
            return;

        default:
            if (root._ignored[key]) return;
            refresh();                    // unknown event: stay correct
            return;
        }
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => root.onEvent(data)
        }
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyWorkspaces(JSON.parse(text)); } catch (e) {}
            }
        }
    }

    Process {
        id: klProc
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applyLayouts(JSON.parse(text)); } catch (e) {}
            }
        }
    }

    // One-time safety net: the stream does send full WorkspacesChanged and
    // KeyboardLayoutsChanged snapshots the moment it connects (verified), so
    // this is redundant in practice — but it costs two forks once per session
    // and removes any dependence on that ordering.
    Component.onCompleted: refresh()
}
