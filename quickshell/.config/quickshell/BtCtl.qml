pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// BlueZ bluetooth backend. Connected device, known/discovered devices,
// paired devices, adapter power, connect/disconnect. Mirrors WifiCtl.
//
// Parity note: WifiCtl's toggle is `nmcli radio wifi on/off` and NM runs
// always. Bluetooth must NOT run always (battery), so the toggle is
// on-demand: ON = `systemctl start bluetooth` + `bluetoothctl power on`,
// OFF = `bluetoothctl power off` + `systemctl stop bluetooth`. Starting a
// system unit unprivileged needs a one-time polkit rule scoped to
// bluetooth.service (see the rule shipped alongside this file); without it
// the toggle silently no-ops (polkit denies the start).
//
// Fail-fast: one short `probe` gates everything. If bluez is unreachable it
// returns empty at 2s and the picker degrades to "off" instead of each
// probe independently blocking its own `timeout` (~14s of "scanning…").
// When bluez IS up the probe is an instant D-Bus call, like nmcli for wifi.
Singleton {
    id: root
    property string activeDevice: ""    // name of first connected device
    property var _raw: []               // [{mac, name}] from `devices`
    property var pairedMacs: []         // MACs of paired devices
    property var connectedMacs: []      // MACs currently connected
    property bool powered: true         // adapter Powered: yes
    property bool available: true       // bluez daemon reachable
    property bool _wantScan: false      // probe should kick a full scan
    readonly property bool scanning: scanProc.running   // discovery in flight
    property bool _powering: false      // power toggle in flight (gate probe)
    property var inRangeMacs: []        // MACs that reported RSSI in latest scan

    // [{mac, name, paired, connected, inRange}] sorted into three tiers:
    // (1) paired & in-range, (2) paired & out-of-range, (3) unpaired —
    // connected-first then by name within each tier. Recomputed when any
    // referenced set changes (deps captured via the function args).
    readonly property var devices: root._buildDevices(
        root._raw, root.pairedMacs, root.connectedMacs, root.inRangeMacs)

    function _buildDevices(raw, paired, connected, inRange) {
        var list = raw.map(function (d) {
            var p = paired.indexOf(d.mac) >= 0;
            var c = connected.indexOf(d.mac) >= 0;
            // connected implies in range; a device can't connect from out of range
            var ir = c || inRange.indexOf(d.mac) >= 0;
            return { mac: d.mac, name: d.name, paired: p, connected: c, inRange: ir };
        });
        list.sort(function (a, b) {
            var ra = a.paired ? (a.inRange ? 0 : 1) : 2;
            var rb = b.paired ? (b.inRange ? 0 : 1) : 2;
            if (ra !== rb) return ra - rb;
            var ca = a.connected ? 0 : 1, cb = b.connected ? 0 : 1;
            if (ca !== cb) return ca - cb;
            var na = (a.name || "").toLowerCase(), nb = (b.name || "").toLowerCase();
            return na < nb ? -1 : (na > nb ? 1 : 0);
        });
        return list;
    }

    function parseDevices(text) {
        // bluetoothctl lines: "Device AA:BB:CC:DD:EE:FF Name With Spaces".
        // MAC has no spaces; name is everything after the first space.
        // Plain string ops only — no regex (Qt V4 lookaround is unsafe).
        var out = [], ls = text.split('\n');
        for (var i = 0; i < ls.length; i++) {
            var l = ls[i];
            if (l.indexOf("Device ") !== 0) continue;
            var rest = l.substring(7);
            var sp = rest.indexOf(" ");
            var mac = sp < 0 ? rest : rest.substring(0, sp);
            var name = sp < 0 ? mac : rest.substring(sp + 1);
            out.push({ mac: mac, name: name });
        }
        return out;
    }

    function parseInRange(text) {
        // bluetoothctl discovery (no tty → no ANSI) emits lines like
        // "[CHG] Device AA:BB:CC:DD:EE:FF RSSI: -72" for devices seen in
        // range. Collect the MAC from any line containing "RSSI:".
        // Plain string ops only — no regex (Qt V4 lookaround is unsafe).
        var out = [], ls = text.split('\n');
        for (var i = 0; i < ls.length; i++) {
            var l = ls[i];
            if (l.indexOf("RSSI:") < 0) continue;
            var di = l.indexOf("Device ");
            if (di < 0) continue;
            var rest = l.substring(di + 7);
            var sp = rest.indexOf(" ");
            var mac = sp < 0 ? rest : rest.substring(0, sp);
            if (out.indexOf(mac) < 0) out.push(mac);
        }
        return out;
    }

    function refreshActive() { root._wantScan = false; probe.running = true; }
    function scan()          { root._wantScan = true;  probe.running = true; }
    function setPowered(on) {
        // Optimistic: flip `powered` immediately so the switch and picker
        // react instantly instead of waiting for the 2.5 s reprobe. On the
        // way down also clear every device set so the list empties at once.
        // reprobe still runs and reconciles (e.g. reverts on polkit-denied
        // start). On-demand daemon: start bluez then power the adapter; on
        // the way down power off then stop bluez (no battery cost).
        root._powering = true;          // a probe that completes mid-transition
                                        // would read the controller's transient
                                        // Powered: no and clobber state — gate it
        root.powered = on;
        if (!on) {
            root._raw = [];
            root.pairedMacs = [];
            root.connectedMacs = [];
            root.inRangeMacs = [];
            root.activeDevice = "";
        }
        if (on)
            // start bluez, then retry `power on` until it sticks: a freshly
            // started daemon reports org.bluez.Error.Busy while the
            // controller initialises, so a single `sleep 1 && power on`
            // races and the adapter never powers (toggle snaps back to off).
            powerSet.command = ["sh", "-c",
                "systemctl start bluetooth || exit 1; for i in $(seq 1 10); do timeout 3 bluetoothctl power on 2>/dev/null | grep -q succeeded && exit 0; sleep 0.5; done; exit 1"];
        else
            powerSet.command = ["sh", "-c",
                "timeout 3 bluetoothctl power off; systemctl stop bluetooth"];
        powerSet.reqOn = on;
        powerSet.running = true;
        // NB: reconcile happens in powerSet.onRunningChanged (when the
        // start+power-on actually finishes), NOT on a fixed timer — the ON
        // command can outlast reprobe's 2.5 s and falsely revert to "off".
    }
    function isPaired(mac) {
        for (var i = 0; i < root.pairedMacs.length; i++)
            if (root.pairedMacs[i] === mac) return true;
        return false;
    }
    function connect(mac, needPair) {
        // Unpaired → pair+trust+connect; paired → straight connect.
        if (needPair)
            connectProc.command = ["sh", "-c",
                "timeout 20 bluetoothctl pair \"$1\"; timeout 8 bluetoothctl trust \"$1\"; timeout 12 bluetoothctl connect \"$1\"",
                "_", mac];
        else
            connectProc.command = ["sh", "-c", "timeout 12 bluetoothctl connect \"$1\"", "_", mac];
        connectProc.running = true;
        reprobe.restart();
    }
    function disconnect(mac) {
        disconnectProc.command = ["sh", "-c", "timeout 8 bluetoothctl disconnect \"$1\"", "_", mac];
        disconnectProc.running = true;
        reprobe.restart();
    }

    // Liveness + power gate. `bluetoothctl show` is an instant D-Bus query
    // when bluez is up; with the daemon down it produces nothing and is
    // killed at 2s. Either way onStreamFinished fires and we branch on it,
    // so no downstream probe ever blocks on a dead daemon.
    Process {
        id: probe
        command: ["sh", "-c", "timeout 2 bluetoothctl show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Ignore probes that land mid power-toggle: a `show` started
                // while the daemon was down can finish just as it comes up and
                // read the controller's transient Powered: no, flipping the
                // toggle off. powerSet owns power state during a transition.
                if (root._powering) return;
                var t = text;
                root.available = t.indexOf("Powered:") >= 0;
                root.powered = root.available && t.indexOf("Powered: yes") >= 0;
                if (!root.available) {           // daemon/adapter down → clear, don't churn
                    root._raw = [];
                    root.pairedMacs = [];
                    root.connectedMacs = [];
                    root.inRangeMacs = [];
                    root.activeDevice = "";
                    return;
                }
                connGet.running = true;          // up: always refresh connected + paired + list
                pairedProc.running = true;
                listProc.running = true;
                if (root._wantScan) scanProc.running = true;
            }
        }
    }
    Process {
        id: connGet
        command: ["sh", "-c", "timeout 4 bluetoothctl devices Connected 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ds = root.parseDevices(text);
                var macs = [];
                for (var i = 0; i < ds.length; i++) macs.push(ds[i].mac);
                root.connectedMacs = macs;
                root.activeDevice = ds.length ? ds[0].name : "";
            }
        }
    }
    // bounded discovery: --timeout makes bluetoothctl exit after 5 s; the
    // outer timeout is a hang-guard. Only started once the probe confirms
    // bluez is up, so a dead daemon never costs the scan window.
    Process {
        id: scanProc
        command: ["sh", "-c", "timeout 6 bluetoothctl --timeout 5 scan on 2>/dev/null"]
        // discovery stream carries RSSI for in-range devices; parse it to
        // learn which devices are reachable right now
        stdout: StdioCollector {
            onStreamFinished: root.inRangeMacs = root.parseInRange(text)
        }
        // devices only appear once discovery has run, so re-list on finish
        onRunningChanged: if (!running) {
            listProc.running = true;
            connGet.running = true;
        }
    }
    Process {
        id: listProc
        command: ["sh", "-c", "timeout 4 bluetoothctl devices 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root._raw = root.parseDevices(text)
        }
    }
    Process {
        id: pairedProc
        command: ["sh", "-c", "timeout 4 bluetoothctl devices Paired 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ds = root.parseDevices(text), macs = [];
                for (var i = 0; i < ds.length; i++) macs.push(ds[i].mac);
                root.pairedMacs = macs;
            }
        }
    }
    // command rebuilt per-call; reqOn records the requested direction. The ON
    // command greps for "succeeded", so its exit code already confirms the
    // controller is powered — trust that instead of re-reading `Powered` via
    // `show`, which can still report "no" for a beat right after success and
    // flip the toggle off→on (a visible blink). Populate devices + scan
    // directly; no racy power re-read.
    Process {
        id: powerSet
        property bool reqOn: false
        // exit code arrives via the `exited` signal, NOT a property — read it
        // here. The ON command greps for "succeeded", so exitCode 0 already
        // confirms the controller is powered; trust that over a racy re-read.
        onExited: (exitCode, exitStatus) => {
            if (reqOn && exitCode === 0) {       // confirmed on
                root.available = true;
                root.powered = true;
                connGet.running = true;
                pairedProc.running = true;
                listProc.running = true;
                scanProc.running = true;         // discovery + scanning feedback
            } else if (reqOn) {                  // start/power-on failed (e.g. polkit)
                root.powered = false;
            }
            // OFF path: optimistic clear in setPowered already applied; the
            // daemon is being stopped, so nothing to confirm.
            root._powering = false;              // transition done — probes trusted again
        }
    }
    Process { id: connectProc }    // command rebuilt per-call
    Process { id: disconnectProc } // command rebuilt per-call
    // after a connect / power toggle, re-probe (which re-lists if bluez is
    // up). 2.5 s clears `systemctl start` + sleep 1 + `power on` so the
    // probe sees Powered: yes rather than catching the transition.
    Timer {
        id: reprobe
        interval: 2500
        onTriggered: { root._wantScan = true; probe.running = true; }
    }
}
