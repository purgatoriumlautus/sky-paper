import QtQuick
import Quickshell
import Quickshell.Wayland

// Top bar — one instance per monitor (shell.qml Variants). Layout:
//   [workspace №]  ···  [clock]  ···  [language] [λ]
//
// The ControlCenter + Launcher do NOT live here — they're single shared popups
// in shell.qml that re-anchor to the focused bar (see shell.qml header for the
// xdg_popup-parenting reason). This bar:
//   - shows only its own output's workspaces (screenName filter)
//   - reports focus to host.focusedBar so the shared popups anchor here
//   - toggles / highlights the shared control-center from its λ cell
PanelWindow {
    id: bar

    // Set by shell.qml's Variants delegate.
    property var host                       // shell root — owns focusedBar
    // Typed (not var!) so `cc.visible` / `launcher.visible` bindings stay
    // reactive — a var reference loses the sub-property change notifications,
    // which is why the λ highlight + clock fade stopped working.
    property ControlCenter cc               // shared ControlCenter
    property Launcher launcher              // shared Launcher

    readonly property string screenName: bar.screen ? bar.screen.name : ""
    readonly property bool isFocused: NiriIpc.focusedOutput === bar.screenName

    // niri focus moved onto this output → make the shared popups anchor here.
    onIsFocusedChanged: if (isFocused && host) host.focusedBar = bar
    Component.onCompleted: if (isFocused && host) host.focusedBar = bar

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "quickshell-bar-" + bar.screenName
    // OnDemand on the focused bar (so the shared popup's xdg-popup grab routes
    // Esc/Q to it); None on the others. Two simultaneously-focusable bar
    // surfaces make Qt mis-track the "topmost grabbing popup" and reparent the
    // popup → wrong position. Only the focused bar ever hosts the popup, so only
    // it needs focus.
    WlrLayershell.keyboardFocus: bar.isFocused ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // left — workspaces (this output only). 9px inset matches niri's gap.
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        Workspaces { screenName: bar.screenName }
    }

    // center — clock. Integer-snapped (centerIn gives fractional x/y → blurry
    // text). Fades out only on the host bar while its launcher owns the center.
    Clock {
        id: clockMod
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: (launcher && launcher.visible && bar.isFocused) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }

    // right — language + control-center icon
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0                       // language & λ cells touch, like #workspaces

        Language {}

        // λ control-center toggle. Blue at rest; white box + dark glyph when the
        // shared CC is open AND anchored to this bar.
        Rectangle {
            id: ccBox
            height: Theme.barHeight
            width: Theme.cellSize
            radius: 0
            color: (cc && cc.visible && bar.isFocused) ? "#FFFFFF" : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: ccIcon
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                renderType: Text.NativeRendering
                font.hintingPreference: Font.PreferFullHinting
                text: "λ"
                color: (cc && cc.visible && bar.isFocused) ? Theme.fg : Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                anchors.fill: parent
                // Clicking λ makes this bar the popup host, then toggles the CC,
                // so it opens on the monitor you clicked.
                onClicked: {
                    if (host) host.focusedBar = bar;
                    if (cc) cc.toggleCc();
                }
            }
        }
    }
}
