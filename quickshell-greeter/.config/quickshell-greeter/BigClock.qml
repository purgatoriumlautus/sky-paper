import QtQuick
import Quickshell

// Big HH:MM with small date below. Mirrors the lock screen's LockClock —
// duplicated because the greeter runs as `greeter` user and can't read
// /home/aru (same reason Theme.qml / Field.qml are duplicated).
Column {
    id: clk
    spacing: 6

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
