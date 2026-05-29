import QtQuick
import Quickshell
import Quickshell.Io

// Wifi cell — 4 pixel signal bars in the bar, hover tooltip shows SSID + IP.
// Reads `iw dev <iface> link` for signal/SSID, `ip -4 -o addr` for IP.
Item {
    id: root
    height: Theme.barHeight
    // wider than a single-char cell: parallelograms span 4 chars, so we add
    // half a cell of breathing room so the gap to Battery matches the
    // language/λ spacing.
    width: Theme.cellSize + 16

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

    // hovered → poll the tooltip-only data (IP + bytes) and run fast.
    // Background mode runs only the cheap signal probe every 30s.
    property bool hovered: false

    function poll() {
        ifaceProc.running = true;
    }

    Timer {
        id: pollTimer
        interval: root.hovered ? 1500 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.poll()
    }

    // 1. find first wireless iface, then kick off followups.
    //    Always: linkProc (cheap, drives signal bars).
    //    Hovered only: ipProc + bytesProc (only used by the tooltip).
    Process {
        id: ifaceProc
        command: ["sh", "-c", "iw dev | awk '/Interface/{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.iface = text.trim();
                if (!root.iface) {
                    root.ssid = ""; root.signalDbm = 0; root.ip = "";
                    root.rxBps = 0; root.txBps = 0;
                    return;
                }
                linkProc.running = true;
                if (root.hovered) { ipProc.running = true; bytesProc.running = true; }
            }
        }
    }

    // 4. throughput — sample rx_bytes/tx_bytes, derive B/s from delta
    Process {
        id: bytesProc
        command: ["sh", "-c", "cat /sys/class/net/" + root.iface + "/statistics/rx_bytes /sys/class/net/" + root.iface + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var nums = text.trim().split('\n');
                if (nums.length < 2) return;
                var rx = parseFloat(nums[0]), tx = parseFloat(nums[1]);
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

    // 2. SSID + signal
    Process {
        id: linkProc
        command: ["sh", "-c", "iw dev " + root.iface + " link"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("Not connected") >= 0) {
                    root.ssid = ""; root.signalDbm = 0; return;
                }
                var s = text.match(/SSID:\s*(.+)/);
                root.ssid = s ? s[1].trim() : "";
                var sig = text.match(/signal:\s*(-?\d+)/);
                root.signalDbm = sig ? parseInt(sig[1]) : 0;
            }
        }
    }

    // 3. IPv4
    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show dev " + root.iface + " 2>/dev/null | awk '{print $4}' | cut -d/ -f1"]
        stdout: StdioCollector {
            onStreamFinished: root.ip = text.trim()
        }
    }

    // 4 inclined parallelograms; filled = lit, hollow = ghost slot (constant width)
    Row {
        spacing: 0
        anchors.centerIn: parent

        Repeater {
            model: 4
            delegate: Text {
                required property int index
                text: index < root.bars ? "▰" : "▱"
                color: index < root.bars ? Theme.fg : Theme.borderDim
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
