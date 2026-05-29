import QtQuick
import Quickshell

// 1:1 with waybar #workspaces. Active = white box full bar height.
// Active state comes from NiriIpc.activeWs (reactive int — no delegate
// rebuild on switch).
Row {
    spacing: 0

    Repeater {
        model: NiriIpc.workspaces

        delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: NiriIpc.activeWs === modelData.idx

            height: Theme.barHeight
            width: Theme.cellSize   // fixed square — same as language & λ
            radius: 0
            color: modelData.urgent ? "#E61F1812"
                 : isActive          ? "#FFFFFF"
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
                     : parent.isActive  ? Theme.fg
                     : modelData.empty   ? Theme.borderDim
                     : Theme.muted
            }
        }
    }
}
