import QtQuick
import Quickshell
import Quickshell.Io

// Layout short name (instant via NiriIpc). Fg text. When the layout changes,
// an accent box blinks behind it (same look as an active workspace — the
// label dips to Theme.bg with it: light fg on the purple fill is unreadable).
// Click = switch to next layout.
Item {
    id: root
    height: Theme.barHeight
    // hug the label + uniform side padding → even gaps in the right cluster
    width: label.implicitWidth + 2 * Theme.cellPad

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 0
        color: "transparent"

        SequentialAnimation {
            id: blink
            ParallelAnimation {
                PropertyAction { target: box; property: "color"; value: Theme.accentSoft }
                PropertyAction { target: label; property: "color"; value: Theme.bg }
            }
            ParallelAnimation {
                ColorAnimation { target: box; property: "color"; to: "transparent"; duration: 280 }
                ColorAnimation { target: label; property: "color"; to: Theme.fg; duration: 280 }
            }
        }
    }

    Text {
        id: label
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferFullHinting
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        text: NiriIpc.layoutShort
        color: Theme.fg
    }

    Connections {
        target: NiriIpc
        function onLayoutShortChanged() { blink.restart(); }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: switchProc.running = true
    }

    Process {
        id: switchProc
        command: ["niri", "msg", "action", "switch-layout", "next"]
    }
}
