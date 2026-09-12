import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// App launcher popup. Backend logic lives in AppLauncher (singleton).
// Opens centered under the bar; type to filter, arrows/Tab to move,
// Enter to launch, Esc to close.
//
// The input is inlined (not Field.qml) on purpose: nav keys (Up/Down/Tab)
// are handled on the focused TextInput itself so it can intercept them
// before its default cursor/focus-traversal behavior, while printable keys
// fall through (event.accepted left false) and type normally.
// Layer surface (NOT a grabbing PopupWindow) — takes keyboard focus itself so a
// keybind opens it instantly. See ControlCenter.qml header for the full why.
PanelWindow {
    id: launcher

    // Focused output's screen (shell.qml). Fallback keeps it valid while hidden.
    property var barScreen
    screen: barScreen ? barScreen : Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: launcher.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Ignore the bar's exclusive zone so y:0 means the true screen top (input row
    // sits ON the bar), not pushed below the reserved bar strip. See ControlCenter.
    exclusionMode: ExclusionMode.Ignore
    // Top, horizontally centered (anchor neither left nor right). The input row
    // sits ON the bar over the faded-out clock; results drop below.
    anchors.top: true

    implicitWidth: 420
    implicitHeight: col.implicitHeight
    visible: false
    color: "transparent"

    property int sel: 0
    property bool closing: false

    // live-filter feeds the singleton; reset selection on every change
    function setQuery(q) { AppLauncher.query = q; launcher.sel = 0; }

    // 0 = fully closed (Δ centered, field collapsed), 1 = fully open
    property real anim: 0

    function open()  { closing = false; visible = true; openAnim.restart(); }
    function close() {
        if (!visible || closing) return;
        closing = true;
        closeAnim.restart();
    }

    NumberAnimation {
        id: openAnim
        target: launcher; property: "anim"; to: 1
        duration: 220; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closeAnim
        target: launcher; property: "anim"; to: 0
        duration: 200; easing.type: Easing.InCubic
        onFinished: { launcher.visible = false; launcher.closing = false; }
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
        AppLauncher.query = "";
        launcher.sel = 0;
        input.forceActiveFocus();   // AFTER visible flip
    }

    function move(dir) {
        var n = AppLauncher.results.length;
        if (n <= 0) { launcher.sel = 0; return; }
        launcher.sel = (launcher.sel + dir + n) % n;
    }
    function commit() {
        var row = AppLauncher.results[launcher.sel];
        if (!row) return;
        if (row.kind === "calc") AppLauncher.copy(row.label);
        else if (row.kind === "run") AppLauncher.run(row.cmd);
        else AppLauncher.launch(row);
        launcher.close();
    }

    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        width: launcher.width
        spacing: 0

        // input row — transparent, bar-height, sits ON the bar (over the
        // faded clock). Δ slides center→left here; prompt + input fade in.
        Item {
            id: inputRow
            width: parent.width
            height: Theme.barHeight

            Text {
                id: glyph
                // anim 0: horizontally centered; anim 1: pinned to left (x=4)
                x: 4 + (1 - launcher.anim) * Math.round((inputRow.width - width) / 2 - 4)
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.launcherGlyph
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
                opacity: launcher.anim
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
                opacity: launcher.anim
                color: Theme.fg
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
                selectByMouse: true
                clip: true
                onTextChanged: launcher.setQuery(text)

                // nav keys intercepted here; printable keys fall through.
                //
                // Ctrl+J / Ctrl+K walk the list: the vim pair, usable in any
                // picker that has a text field in it — fzf and fzf-lua already
                // work this way (docs/keybinds.md §5.3). Matched on
                // event.text as well so the Cyrillic layout hits the same
                // physical keys (Qt's event.key is unreliable there).
                Keys.onPressed: (event) => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                    const t = (event.text || "").toLowerCase();
                    if (event.key === Qt.Key_Escape) {
                        launcher.close(); event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_J || t === "о" || t === "\n")) {
                        launcher.move(+1); event.accepted = true;
                    } else if (ctrl && (event.key === Qt.Key_K || t === "л")) {
                        launcher.move(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Down
                               || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                        launcher.move(+1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up
                               || event.key === Qt.Key_Backtab
                               || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        launcher.move(-1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        launcher.commit(); event.accepted = true;
                    }
                    // everything else: accepted stays false → types normally
                }
            }
        }

        // results box — drops BELOW the bar. Only shown when there are
        // matches; carries the boxFill bg + 1px accent border.
        Rectangle {
            id: resultsBox
            width: parent.width
            color: Theme.barBg     // exact bar color+opacity → reads as the bar extended
            border.width: 0
            radius: 0
            visible: list.count > 0 && launcher.anim > 0.01
            height: visible ? list.height + 12 : 0
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            ListView {
                id: list
                x: 6; y: 6
                width: parent.width - 12
                height: Math.min(count, 5) * 24 * launcher.anim
                opacity: launcher.anim
                clip: true
                interactive: false
                model: AppLauncher.results
                currentIndex: launcher.sel
                delegate: Rectangle {
                    width: list.width
                    height: 24
                    color: index === launcher.sel ? Theme.accentSoft : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: index === launcher.sel ? Theme.bg : Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.hintingPreference: Font.PreferFullHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                        width: list.width - 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { launcher.sel = index; launcher.commit(); }
                    }
                }
            }
        }
    }

    // IPC handler lifted to shell.qml (single instance broadcasts over `bus`);
    // the per-bar Launcher is driven from Bar.qml's Connections so it opens on
    // the focused monitor only.
}
