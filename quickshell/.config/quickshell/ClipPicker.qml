import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Clipboard-history picker. Backend logic lives in ClipHist (singleton).
// Same surface as the launcher — top, centered, input row ON the bar — only
// wider, because clipboard rows are text, not app names, and a 420px row
// elides most of them into uselessness.
//
// Layer surface (NOT a grabbing PopupWindow) and inlined TextInput for the
// same two reasons the launcher has them: instant keyboard focus from a
// keybind, and nav keys intercepted on the focused input before its own
// cursor/traversal handling. See Launcher.qml / ControlCenter.qml.
PanelWindow {
    id: picker

    // Один пикер на все мониторы: переезжает на экран сфокусированного бара,
    // так же как ControlCenter и Launcher (см. шапку shell.qml).
    property var barScreen
    screen: barScreen ? barScreen : Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clip"
    WlrLayershell.keyboardFocus: picker.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true

    implicitWidth: 700
    implicitHeight: col.implicitHeight
    visible: false
    color: "transparent"

    property int sel: 0
    property bool closing: false

    // rows visible at once; the view scrolls to keep `sel` inside
    readonly property int maxRows: 8
    readonly property int rowHeight: 24

    // 0 = fully closed (Ξ centered, field collapsed), 1 = fully open. Same
    // move as the launcher — Ξ slides center→left over the fading clock —
    // but ~2.5x quicker: picking a past copy is a transit gesture, and the
    // launcher's easing is long enough here to be waited on.
    property real anim: 0

    function open()  { closing = false; ClipHist.reload(); visible = true; openAnim.restart(); }
    function close() {
        if (!visible || closing) return;
        closing = true;
        closeAnim.restart();
    }

    NumberAnimation {
        id: openAnim
        target: picker; property: "anim"; to: 1
        duration: 136; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closeAnim
        target: picker; property: "anim"; to: 0
        duration: 120; easing.type: Easing.InCubic
        onFinished: { picker.visible = false; picker.closing = false; }
    }

    property double lastToggle: 0
    function toggle() {
        var now = Date.now();
        if (now - lastToggle < 200) return;
        lastToggle = now;
        visible ? close() : open();
    }

    onVisibleChanged: if (visible) {
        input.text = "";
        ClipHist.query = "";
        picker.sel = 0;
        input.forceActiveFocus();   // AFTER visible flip
    }

    function move(dir) {
        var n = ClipHist.results.length;
        if (n <= 0) { picker.sel = 0; return; }
        picker.sel = (picker.sel + dir + n) % n;
    }
    function commit() {
        var row = ClipHist.results[picker.sel];
        if (!row) return;
        ClipHist.copy(row);
        picker.close();
    }
    // Ctrl+d: drop the row, keep the picker open, keep the cursor where it
    // was so a run of deletes needs no re-aiming.
    function drop() {
        var row = ClipHist.results[picker.sel];
        if (!row) return;
        ClipHist.remove(row);
        var n = ClipHist.results.length;
        if (picker.sel >= n) picker.sel = Math.max(0, n - 1);
    }

    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        width: picker.width
        spacing: 0

        // input row — transparent, bar-height, sits ON the bar
        Item {
            id: inputRow
            width: parent.width
            height: Theme.barHeight

            Text {
                id: glyph
                // anim 0: horizontally centered; anim 1: pinned to left (x=4)
                x: 4 + (1 - picker.anim) * Math.round((inputRow.width - width) / 2 - 4)
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.clipGlyph
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
            }

            Text {
                id: prompt
                anchors.left: glyph.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: ">"
                opacity: picker.anim
                color: input.activeFocus ? Theme.accentText : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
            }

            TextInput {
                id: input
                anchors.left: prompt.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: picker.anim
                color: Theme.fg
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
                selectByMouse: true
                clip: true
                onTextChanged: { ClipHist.query = text; picker.sel = 0; }

                // nav keys intercepted here; printable keys fall through.
                // Cyrillic is matched on event.text because Qt's event.key is
                // unreliable under a non-Latin layout — same as the launcher.
                Keys.onPressed: (event) => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    const t = (event.text || "").toLowerCase();
                    if (event.key === Qt.Key_Escape) {
                        picker.close(); event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_J || t === "о" || t === "\n")) {
                        picker.move(+1); event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_K || t === "л")) {
                        picker.move(-1); event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_D || t === "в")) {
                        picker.drop(); event.accepted = true;
                    } else if (event.key === Qt.Key_Down
                               || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                        picker.move(+1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up
                               || event.key === Qt.Key_Backtab
                               || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        picker.move(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        picker.commit(); event.accepted = true;
                    }
                    // everything else: accepted stays false → types normally
                }
            }
        }

        // results box — drops BELOW the bar, bar color+opacity so it reads as
        // the bar extended. Same construction as the launcher's.
        Rectangle {
            id: resultsBox
            width: parent.width
            color: Theme.barBg
            border.width: 0
            radius: 0
            visible: list.count > 0 && picker.anim > 0.01
            height: visible ? list.height + 12 : 0
            Behavior on height { NumberAnimation { duration: 96; easing.type: Easing.OutCubic } }

            ListView {
                id: list
                x: 6; y: 6
                width: parent.width - 12
                height: Math.min(count, picker.maxRows) * picker.rowHeight * picker.anim
                opacity: picker.anim
                clip: true
                interactive: false
                model: ClipHist.results
                currentIndex: picker.sel
                // history is longer than the window: keep the cursor on screen
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    width: list.width
                    height: picker.rowHeight
                    color: index === picker.sel ? Theme.accentSoft : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: index === picker.sel ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.hintingPreference: Font.PreferFullHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                        width: list.width - 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { picker.sel = index; picker.commit(); }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "clip"
        function toggle(): void { picker.toggle(); }
        function open(): void { picker.open(); }
        function close(): void { picker.close(); }
    }
}
