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
//   WorkspacesChanged        full snapshot        -> applied directly
//   KeyboardLayoutsChanged   {names, current_idx} -> applied directly
//   KeyboardLayoutSwitched   {idx}                -> resolved against cached names
//   WorkspaceActivated       {id, focused}        -> resolved against cached id->row
//
// Two workspace deltas still re-read the snapshot, deliberately: their payload
// field names are NOT verified here (they were not observed in the captured
// stream), and guessing them would fail silently. One fork is the honest price
// for that, and they are rare (urgency; last window of a workspace closing).
//
// Anything unknown falls through to a full refresh, so a future niri that adds
// an event type degrades to the old behaviour instead of going stale.
//
// MULTI-OUTPUT: unlike a single-screen shell, `workspaces` here carries the
// output each workspace lives on, so OutputConfigChanged is deliberately NOT in
// the ignored list — plugging or re-arranging a monitor re-homes workspaces and
// has to rebuild the strip.
Singleton {
    id: root

    // ---- public interface (unchanged) -------------------------------------
    // [{ idx, output, urgent, empty }] sorted by (output, idx). Reassigned
    // ONLY when the set actually changes (dedupe) so delegates don't rebuild
    // on every event. NOTE: per-output "active" is deliberately NOT in here —
    // it lives in activeByOutput so a workspace switch updates the highlight
    // without rebuilding the strip.
    property var workspaces: []
    // { "DP-3": idx, "DP-2": idx } — each output's currently-shown workspace.
    // Cheap object, reassigned on change; drives per-monitor highlight.
    property var activeByOutput: ({})
    // output name of the globally focused workspace (the monitor the user is
    // on). Routes the control-center / launcher / clipboard popups to the
    // right bar.
    property string focusedOutput: ""
    // two-letter layout tag; Language.qml blinks on its change.
    property string layoutShort: ""

    // ---- internal state ---------------------------------------------------
    property string _wsCache: ""       // dedupe key for `workspaces`
    property var    _wsRaw: []         // raw payload, kept for the id -> row map
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
        "ConfigLoaded": 1,
        "CastsChanged": 1
    })

    function refresh() {
        wsProc.running = true;
        klProc.running = true;
    }

    // ---- payload appliers, shared by the stream and by the msg fallbacks ---
    function applyWorkspaces(arr) {
        var sorted = arr.slice().sort((a, b) => a.output === b.output
            ? a.idx - b.idx
            : (a.output < b.output ? -1 : 1));
        root._wsRaw = sorted;
        var list = sorted.map(w => ({
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
        root._applyActive();
    }

    // Derive activeByOutput + focusedOutput from _wsRaw. Split out because the
    // WorkspaceActivated fast path mutates _wsRaw and needs the same recompute
    // without going near the dedupe key.
    function _applyActive() {
        var raw = root._wsRaw;
        var act = {};
        for (var i = 0; i < raw.length; i++)
            if (raw[i].is_active) act[raw[i].output] = raw[i].idx;
        root.activeByOutput = act;
        var f = raw.find(w => w.is_focused);
        root.focusedOutput = f ? f.output : "";
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

        // Activation is per-OUTPUT: only the rows on the activated workspace's
        // own monitor change their is_active. `focused` additionally says the
        // user moved to that monitor, so is_focused is rewritten globally.
        case "WorkspaceActivated": {
            var raw = root._wsRaw;
            var target = raw.find(w => w.id === ev[key].id);
            if (target === undefined) { wsProc.running = true; return; }  // cache stale
            for (var i = 0; i < raw.length; i++) {
                if (raw[i].output === target.output)
                    raw[i].is_active = (raw[i].id === target.id);
                if (ev[key].focused)
                    raw[i].is_focused = (raw[i].id === target.id);
            }
            root._wsRaw = raw;
            root._applyActive();
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
