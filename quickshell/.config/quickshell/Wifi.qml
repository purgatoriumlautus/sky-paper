import QtQuick
import Quickshell
import Quickshell.Io

// Wifi cell — 4 pixel signal bars in the bar, hover tooltip shows SSID + IP.
// Reads `iw dev <iface> link` for signal/SSID, `ip -4 -o addr` for IP.
Item {
    id: root
    height: Theme.barHeight
    // hug the 4 dots + uniform side padding, so the gap to Battery matches
    // every other right-cluster gap (2*cellPad).
    width: dots.implicitWidth + 2 * Theme.cellPad

    property var anchorWin

    property string iface: ""
    property string ssid: ""
    property int signalDbm: 0       // 0 = unknown / disconnected
    property string ip: ""

    // throughput sampling: prev counters + timestamp → current B/s
    property real prevRx: -1
    property real prevTx: -1
    property real prevT: 0
    property real rxBps: 0
    property real txBps: 0

    function fmtRate(bps) {
        if (bps < 1024) return bps.toFixed(0) + " B/s";
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s";
        return (bps / 1024 / 1024).toFixed(2) + " MB/s";
    }

    // 0..4 lit bars, derived from dBm. -30=4, -60=3, -70=2, -80=1, worse=0
    readonly property int bars: {
        if (!ssid) return 0;
        if (signalDbm >= -50) return 4;
        if (signalDbm >= -60) return 3;
        if (signalDbm >= -70) return 2;
        if (signalDbm >= -80) return 1;
        return 0;
    }

    // hovered → also poll the IP (tooltip-only). Background mode runs just the
    // link probe, which is a single process and already carries everything the
    // bar needs.
    //
    // What changed and why: this used to spawn 5 processes per idle tick and up
    // to 11 per hover tick. Three causes, all removed:
    //   1. every tick re-discovered the interface name with `iw dev | awk` —
    //      3 processes for a value that does not change while the machine runs;
    //   2. every probe went through `sh -c "…"`, so a pipeline cost sh + each
    //      stage. Process takes an argv array; no shell is needed;
    //   3. throughput was read from /sys/class/net/*/statistics separately,
    //      but `iw dev <iface> link` ALREADY prints "RX: N bytes" / "TX: N bytes"
    //      — the byte counters come free with the signal probe.
    // Now: 1 process per idle tick, 2 per hover tick. Parsing moved into QML,
    // which is where awk/cut were doing work the JS engine can do for nothing.
    //
    // Note on the counters: `iw link` bytes are per-association and reset on
    // reconnect, unlike the lifetime counters in /sys. The Math.max(0, …) below
    // already absorbs that — one tick reads 0 B/s after a reconnect.
    property bool hovered: false

    function poll() {
        // The interface name is cached: discovered once, reused after that.
        if (!root.iface) { ifaceProc.running = true; return; }
        linkProc.running = true;
        if (root.hovered) ipProc.running = true;
    }

    Timer {
        id: pollTimer
        interval: root.hovered ? 1500 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.poll()
    }

    // 1. Interface discovery — runs once, then only if the interface vanishes.
    //    `iw dev` also lists the P2P "Unnamed/non-netdev interface"; the regex
    //    anchors on a capitalised "Interface" at line start, which that line
    //    does not have.
    Process {
        id: ifaceProc
        command: ["iw", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/^\s*Interface\s+(\S+)/m);
                root.iface = m ? m[1] : "";
                if (!root.iface) {
                    root.ssid = ""; root.signalDbm = 0; root.ip = "";
                    root.rxBps = 0; root.txBps = 0;
                    return;
                }
                root.poll();          // iface now cached → falls through to linkProc
            }
        }
    }

    // 2. One probe for everything the bar and tooltip show: SSID, signal, bytes.
    Process {
        id: linkProc
        command: ["iw", "dev", root.iface, "link"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    // interface gone (rfkill, adapter removed) → re-discover next tick
                    root.iface = ""; root.ssid = ""; root.signalDbm = 0; root.ip = "";
                    root.rxBps = 0; root.txBps = 0;
                    root.prevRx = -1; root.prevTx = -1;
                    return;
                }
                if (text.indexOf("Not connected") >= 0) {
                    root.ssid = ""; root.signalDbm = 0;
                    root.rxBps = 0; root.txBps = 0;
                    root.prevRx = -1; root.prevTx = -1;
                    return;
                }
                var s = text.match(/SSID:\s*(.+)/);
                root.ssid = s ? s[1].trim() : "";
                var sig = text.match(/signal:\s*(-?\d+)/);
                root.signalDbm = sig ? parseInt(sig[1]) : 0;

                var rxm = text.match(/RX:\s*(\d+)\s*bytes/);
                var txm = text.match(/TX:\s*(\d+)\s*bytes/);
                if (rxm && txm) {
                    var rx = parseFloat(rxm[1]), tx = parseFloat(txm[1]);
                    var now = Date.now() / 1000;
                    if (root.prevRx >= 0 && now > root.prevT) {
                        var dt = now - root.prevT;
                        root.rxBps = Math.max(0, (rx - root.prevRx) / dt);
                        root.txBps = Math.max(0, (tx - root.prevTx) / dt);
                    }
                    root.prevRx = rx; root.prevTx = tx; root.prevT = now;
                }
            }
        }
    }

    // 3. IPv4 — tooltip only, hover-gated.
    Process {
        id: ipProc
        command: ["ip", "-4", "-o", "addr", "show", "dev", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/\binet\s+(\d+\.\d+\.\d+\.\d+)/);
                root.ip = m ? m[1] : "";
            }
        }
    }

    // 4 dots; lit = solid ●, unlit = hollow ○. Both are bitmap-native in
    // Terminess — unlike the old ▰/▱ parallelograms, which Terminess lacks: a
    // Noto fallback drew them, and the 2026-06 fontconfig/noto-fonts update
    // made that fallback render oversized & misaligned (too wide, overlapping
    // the battery).
    Row {
        id: dots
        spacing: 0
        anchors.centerIn: parent

        Repeater {
            model: 4
            delegate: Text {
                required property int index
                readonly property bool lit: index < root.bars
                text: lit ? "●" : "○"
                color: lit ? Theme.fg : Theme.borderDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            root.hovered = true;
            // reset throughput baseline so the first sample isn't a huge spike
            root.prevRx = -1; root.prevTx = -1; root.rxBps = 0; root.txBps = 0;
            root.poll();
            tooltip.visible = true;
        }
        onExited: {
            root.hovered = false;
            tooltip.visible = false;
        }
    }

    PopupWindow {
        id: tooltip
        anchor.window: anchorWin
        anchor.rect.x: anchorWin
            ? Math.round(root.mapToItem(anchorWin.contentItem, 0, 0).x) + root.width - tooltip.width
            : 0
        anchor.rect.y: anchorWin ? anchorWin.height : 0
        implicitWidth:  body.implicitWidth + 16
        implicitHeight: body.implicitHeight + 12
        visible: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.barBg
            border.width: 0

            Column {
                id: body
                anchors.centerIn: parent
                spacing: 2

                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    text: root.ssid || "disconnected"
                    color: Theme.fg
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    text: root.ip || "—"
                    color: Theme.muted
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    text: "↓ " + root.fmtRate(root.rxBps) + "  ↑ " + root.fmtRate(root.txBps)
                    color: Theme.muted
                }
            }
        }
    }
}
