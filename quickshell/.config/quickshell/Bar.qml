import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Top bar. Layout: [workspace №]  ···  [clock]  ···  [language] [⊞]
PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "quickshell-bar"
    // The bar never needs keyboard focus: the control-center / launcher are
    // their own keyboard-focusable layer surfaces (they don't grab through the
    // bar), and the λ click is a pointer event (unaffected by keyboardFocus).
    // None keeps the bar out of the keyboard-focus chain entirely.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // left — workspaces. 12px inset, symmetric with the right edge (λ).
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 9          // matches niri's visible per-side window gap
        anchors.verticalCenter: parent.verticalCenter
        Workspaces {}
    }

    // center — clock. Integer-snapped position (centerIn gives fractional
    // x/y → Qt Quick renders text blurry; Pango always pixel-snaps).
    // Fades out while the launcher or the clipboard picker owns the center.
    Clock {
        id: clockMod
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: launcher.visible || clip.visible ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // right — language + control-center icon
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 9          // matches niri's visible per-side window gap          // symmetric with left workspace inset
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0                       // language & λ cells touch, like #workspaces

        Wifi    { anchorWin: bar }
        Battery { anchorWin: bar }

        Language {}

        // λ control-center toggle. Same fixed box as a workspace/language
        // cell: purple at rest, accent box + dark glyph when selected (open).
        Rectangle {
            id: ccBox
            height: Theme.barHeight
            // hug the λ glyph + uniform side padding → even gaps in the cluster
            width: ccIcon.implicitWidth + 2 * Theme.cellPad
            radius: 0
            color: cc.visible ? Theme.accentSoft : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: ccIcon
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "λ"
                color: cc.visible ? Theme.bg : Theme.accentText   // purple at rest
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                anchors.fill: parent
                onClicked: cc.toggleCc()
            }
        }
    }

    ControlCenter { id: cc }

    Launcher { id: launcher }

    ClipPicker { id: clip }

    // One keyboard surface at a time. CC, launcher and picker each take
    // exclusive keyboard focus and each sit on the bar, so opening one closes
    // the other two. Wired here rather than inside the components: none of
    // them can see the others' ids, and a second `onVisibleChanged` written on
    // an instance would REPLACE the handler the component declares (focus +
    // query reset), not add to it. No loop — the close functions start an
    // animation and leave `visible` true until it finishes.
    Connections {
        target: cc
        function onVisibleChanged() { if (cc.visible) { launcher.close(); clip.close(); } }
    }
    Connections {
        target: launcher
        function onVisibleChanged() { if (launcher.visible) { cc.closeCc(); clip.close(); } }
    }
    Connections {
        target: clip
        function onVisibleChanged() { if (clip.visible) { cc.closeCc(); launcher.close(); } }
    }

    // niri binds:
    //   Mod+Space     → `qs ipc call controlcenter toggle`      (lands on row 0, power hidden)
    //   Mod+Shift+E   → `qs ipc call controlcenter togglePower` (reveals power, lands on Lock)
    //
    // togglePower semantics:
    //   CC closed                     → open CC, show power, focus Lock
    //   CC open & power visible       → close CC (toggle)
    //   CC open & power NOT visible   → show power, focus Lock (don't close)
    //
    // Esc inside the power section hides it and returns focus to row 0
    // without closing the CC. Note: ControlCenter.onVisibleChanged
    // synchronously resets focusedRow to 0 and powerVisible to false on
    // open, so we set both AFTER openCc().
    // Keep-awake. CC "Auto-suspend" off → hold a Wayland idle inhibitor on the
    // bar surface, which is always mapped. niri then stops reporting idle and
    // swayidle's whole timeline pauses (dim, lock+screen-off, suspend), so the
    // screen stays on. Lid close is unaffected and always suspends — see
    // SuspendInhibit.qml for why the two earlier mechanisms were wrong.
    IdleInhibitor {
        window: bar
        enabled: !SuspendInhibit.enabled
    }

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { cc.toggleCc(); }
        // keepAwake: inverse of the row label — true = stay awake, screen on.
        function keepAwake(on: bool): void { SuspendInhibit.enabled = !on; }
        function keepAwakeState(): string { return SuspendInhibit.enabled ? "off" : "on"; }
        function open(): void { cc.openCc(); }
        function close(): void { cc.closeCc(); }
        function togglePower(): void {
            if (cc.visible && !cc.closing && cc.powerVisible) {
                cc.closeCc();
                return;
            }
            if (!cc.visible || cc.closing) cc.openCc();
            cc.powerVisible = true;
            cc.focusedRow = 10;
            cc.footerCol = 0;
        }
    }
}
