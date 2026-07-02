import QtQuick
import Quickshell
import Quickshell.Io

// Battery cell — capacity in the bar, hover tooltip shows estimated time + W.
// Reads /sys/class/power_supply/BAT0/uevent directly (no upower dep).
Item {
    id: root
    height: Theme.barHeight
    // hug the % text + uniform side padding → even gaps to wifi & language
    width: pct.implicitWidth + 2 * Theme.cellPad

    // anchor window for the tooltip popup (the bar)
    property var anchorWin

    property int capacity: 0
    property string status: ""
    property real powerW: 0          // current draw in W
    property real energyNowWh: 0
    property real energyFullWh: 0

    // hover → faster poll for the tooltip; background poll stays slow
    property bool hovered: false

    function poll() { uevent.running = true }

    Timer {
        interval: root.hovered ? 2000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.poll()
    }

    Process {
        id: uevent
        command: ["cat", "/sys/class/power_supply/BAT0/uevent"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split('\n');
                for (var i = 0; i < lines.length; ++i) {
                    var idx = lines[i].indexOf('=');
                    if (idx < 0) continue;
                    var k = lines[i].substring(0, idx);
                    var v = lines[i].substring(idx + 1);
                    if (k === "POWER_SUPPLY_CAPACITY")    root.capacity     = parseInt(v);
                    else if (k === "POWER_SUPPLY_STATUS") root.status       = v;
                    else if (k === "POWER_SUPPLY_POWER_NOW")    root.powerW       = parseInt(v) / 1e6;
                    else if (k === "POWER_SUPPLY_ENERGY_NOW")   root.energyNowWh  = parseInt(v) / 1e6;
                    else if (k === "POWER_SUPPLY_ENERGY_FULL")  root.energyFullWh = parseInt(v) / 1e6;
                }
            }
        }
    }

    function timeRemaining() {
        if (powerW <= 0.01) return "—";
        var h = (status === "Charging")
            ? Math.max(0, (energyFullWh - energyNowWh)) / powerW
            : energyNowWh / powerW;
        var totalMin = Math.round(h * 60);
        var hh = Math.floor(totalMin / 60);
        var mm = totalMin % 60;
        return hh + "h " + (mm < 10 ? "0" : "") + mm + "m";
    }

    Text {
        id: pct
        anchors.centerIn: parent
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: root.capacity + "%"
        color: root.status === "Charging" ? Theme.accentText : Theme.fg
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { root.hovered = true; root.poll(); tooltip.openTt(); }
        onExited:  { root.hovered = false; tooltip.closeTt(); }
    }

    PopupWindow {
        id: tooltip
        anchor.window: anchorWin
        // align tooltip's right edge with the cell's right edge
        anchor.rect.x: anchorWin
            ? Math.round(root.mapToItem(anchorWin.contentItem, 0, 0).x) + root.width - tooltip.width
            : 0
        anchor.rect.y: anchorWin ? anchorWin.height : 0
        implicitWidth:  body.implicitWidth + 16
        implicitHeight: body.implicitHeight + 12
        visible: false
        color: "transparent"

        function openTt() { visible = true }
        function closeTt() { visible = false }

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
                    text: root.timeRemaining() + (root.status === "Charging" ? " until full" : " left")
                    color: Theme.fg
                }
                Text {
                    renderType: Text.NativeRendering
                    font.hintingPreference: Font.PreferFullHinting
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    text: root.powerW.toFixed(2) + " W"
                    color: Theme.muted
                }
            }
        }
    }
}
