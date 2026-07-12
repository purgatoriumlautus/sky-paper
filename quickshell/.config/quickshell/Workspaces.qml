import QtQuick
import Quickshell

// Per-monitor workspace strip. `screenName` filters NiriIpc.workspaces to this
// output so each bar shows only its own monitor's workspaces; the accent box
// tracks that output's active workspace (NiriIpc.activeByOutput) — a reactive
// lookup, so switching doesn't rebuild the delegates.
Row {
    id: wsRoot
    property string screenName: ""
    spacing: 0

    Repeater {
        model: NiriIpc.workspaces.filter(w => w.output === wsRoot.screenName)

        delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: NiriIpc.activeByOutput[wsRoot.screenName] === modelData.idx

            height: Theme.barHeight
            width: Theme.cellSize   // fixed square — same as language & λ
            radius: 0
            color: modelData.urgent ? Qt.alpha(Theme.warn, 0.9)
                 : isActive          ? Theme.accentSoft
                 : "transparent"

            Text {
                id: label
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                text: modelData.idx
                color: modelData.urgent ? Theme.bg
                     : parent.isActive  ? Theme.bg
                     : modelData.empty   ? Theme.borderDim
                     : Theme.muted
            }
        }
    }
}
