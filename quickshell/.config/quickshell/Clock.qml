import QtQuick
import Quickshell

// dd.MM HH:mm — Minutes precision so there is no per-second wakeup (battery).
Text {
    // NativeRendering: crisp bitmap strike (no distance-field blur).
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferFullHinting
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clk.date, "dd.MM HH:mm")
}
