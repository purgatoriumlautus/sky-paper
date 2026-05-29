pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager wifi: active SSID, visible networks, saved profiles, connect.
Singleton {
    id: root
    property string activeSsid: ""
    property var networks: []       // [{ssid, signal, secured, active}]
    property var savedSsids: []     // names of saved NM connections
    property bool enabled: true     // `nmcli radio wifi`
    property bool scanning: false   // discovery window open (see scan())

    function refreshActive() { ssidGet.running = true; radioGet.running = true; }
    function scan() {
        // `nmcli dev wifi rescan` returns immediately while results arrive
        // over a few seconds, so `scanning` can't track a process — open a
        // fixed window here and let scanWindow close it (the post-rescan
        // re-list also fires from that timer).
        root.scanning = true;
        scanWindow.restart();
        radioGet.running = true;
        scanProc.running = true;
        listProc.running = true;
        conListProc.running = true;
    }
    function setEnabled(on) {
        radioSet.command = ["nmcli", "radio", "wifi", on ? "on" : "off"];
        radioSet.running = true;
        reprobe.restart();
    }
    function isSaved(ssid) {
        for (var i = 0; i < root.savedSsids.length; i++)
            if (root.savedSsids[i] === ssid) return true;
        return false;
    }
    function connect(ssid, password) {
        // Saved profile or open network → direct; secured + unknown → --ask.
        if (password) {
            // via env so it never lands in argv / /proc/<pid>/cmdline
            connectProc.environment = { PASS: password };
            connectProc.command = ["sh", "-c", "printf '%s\\n' \"$PASS\" | nmcli --ask dev wifi connect \"$1\"", "_", ssid];
        } else {
            connectProc.environment = {};
            connectProc.command = ["sh", "-c", "nmcli dev wifi connect \"$1\"", "_", ssid];
        }
        connectProc.running = true;
        reprobe.restart();
    }
    function disconnect(ssid) {
        // NM names the wifi profile after the SSID; bring that connection down.
        disconnectProc.command = ["sh", "-c", "nmcli con down id \"$1\"", "_", ssid];
        disconnectProc.running = true;
        reprobe.restart();
    }

    Process {
        id: ssidGet
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE c show --active | awk -F: '$2==\"802-11-wireless\"{print $1; exit}'"]
        stdout: StdioCollector { onStreamFinished: root.activeSsid = text.trim() }
    }
    Process { id: scanProc; command: ["nmcli", "dev", "wifi", "rescan"] }
    Process {
        id: listProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split('\n');
                var seen = {};
                for (var i = 0; i < lines.length; i++) {
                    // nmcli -t escapes : in fields as \: . Qt's V4 engine has
                    // no regex lookbehind (it silently never matches), so
                    // mask escaped colons with \x01, split on :, then restore.
                    var raw = lines[i];
                    if (!raw) continue;
                    var parts = raw.replace(/\\:/g, "\x01").split(":");
                    if (parts.length < 4) continue;
                    var ssid = parts[1].replace(/\x01/g, ":");
                    if (!ssid) continue;
                    var sig = parseInt(parts[2]) || 0;
                    if (!seen[ssid] || seen[ssid].signal < sig)
                        seen[ssid] = { ssid: ssid, signal: sig, secured: parts[3] !== "", active: parts[0] === "*" };
                }
                var out = [];
                for (var k in seen) out.push(seen[k]);
                out.sort(function(a, b) { return b.signal - a.signal; });
                root.networks = out;
            }
        }
    }
    Process {
        id: conListProc
        command: ["sh", "-c", "nmcli -t -f NAME con show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.savedSsids = text.split('\n').filter(function(s) { return s.length > 0; })
        }
    }
    Process {
        id: radioGet
        command: ["sh", "-c", "nmcli -t radio wifi"]
        stdout: StdioCollector { onStreamFinished: root.enabled = text.trim() === "enabled" }
    }
    Process { id: radioSet }       // command rebuilt per-call
    Process { id: connectProc }    // command rebuilt per-call
    Process { id: disconnectProc } // command rebuilt per-call
    // after a connect / radio toggle, re-read active SSID, radio state, and list
    Timer {
        id: reprobe
        interval: 1500
        onTriggered: { ssidGet.running = true; radioGet.running = true; listProc.running = true; }
    }
    // scan feedback window: rescan completes in the background shortly after
    // nmcli returns; NM is usually quick, so hold `scanning` 1.5s then re-list.
    Timer {
        id: scanWindow
        interval: 1500
        onTriggered: { root.scanning = false; listProc.running = true; }
    }
}
