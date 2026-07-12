import QtQuick
import Quickshell

// Lock-screen clock: big HH:MM with small date below. Minute precision so
// it doesn't wake the system every second (laptop battery).
Column {
    id: clk
    spacing: 6

    // Qt timers run on CLOCK_MONOTONIC, which freezes during suspend, so on
    // resume `sys` keeps showing the pre-suspend minute until its overdue tick
    // finally fires. Toggling `enabled` forces an immediate re-read; the lock
    // screen calls this from wake() so the time is correct the instant the
    // screen comes back.
    function refresh() { sys.enabled = false; sys.enabled = true }

    SystemClock {
        id: sys
        precision: SystemClock.Minutes
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(sys.date, "HH:mm")
        color: Theme.fgMax
        font.family: Theme.fontFamily
        font.pixelSize: 160
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(sys.date, "ddd, d MMM")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 24
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
    }
}
