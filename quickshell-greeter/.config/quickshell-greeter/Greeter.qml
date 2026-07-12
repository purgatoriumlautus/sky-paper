import QtQuick
import Quickshell
import Quickshell.Io

// Greeter — visually mirrors the user-shell lock screen.
//
// Three-stage state machine (awake, revealed):
//   1. asleep    awake=false, revealed=false → full black overlay, nothing
//      visible. First key/click only wakes; no inject, no reveal.
//   2. awake     awake=true,  revealed=false → black fades, BigClock + dim
//      wallpaper visible.
//   3. revealed  awake=true,  revealed=true  → collapsing slot under the
//      clock grows to 180px; Column { centerIn: parent } re-centers,
//      "pushing" the clock up to make room for the LoginBox.
//
// NOT a PanelWindow/layer-shell: cage (the kiosk compositor greetd runs us in)
// does not implement wlr-layer-shell, so a layer surface never maps -> blank
// screen. cage auto-fullscreens its single xdg-toplevel client, same as the
// GTK regreet toplevel that worked here before.
FloatingWindow {
    id: root

    visible: true
    color: "transparent"
    // cage forces fullscreen for its lone client; explicit so a stray
    // non-cage run (debugging) also covers the screen.
    fullscreen: true

    // Greeter starts awake (clock visible). The internal idle timer below
    // flips awake → false after 10 min with no key/click activity (the
    // greeter user has no swayidle, so this gate lives in QML).
    property bool awake: true
    property bool revealed: false

    function wake() { awake = true; idleTimer.restart() }

    function reveal() {
        if (revealed) return
        revealed = true
        focusDelay.restart()
        idleTimer.restart()
    }

    // Power keys, live in every state (asleep / clock / revealed):
    //   F1 → suspend, F2 → power off, F5 → reboot.
    // greetd's session is the active session on seat0/vt1, so polkit's
    // allow_active grants suspend/poweroff/reboot without a password.
    function handlePowerKey(event) {
        if (event.key === Qt.Key_F1)      { suspendProc.running  = true; event.accepted = true; return true }
        else if (event.key === Qt.Key_F2) { poweroffProc.running = true; event.accepted = true; return true }
        else if (event.key === Qt.Key_F5) { rebootProc.running   = true; event.accepted = true; return true }
        return false
    }

    // 10-min idle → asleep (full black). Any key/click restarts via wake()
    // or the surface's input handlers below.
    Timer {
        id: idleTimer
        interval: 600 * 1000
        repeat: false
        running: true
        onTriggered: root.awake = false
    }

    Item {
        id: surface
        anchors.fill: parent
        focus: true

        // Wallpaper. Installed path; install.sh copies mntvagaflexoki.png here.
        Image {
            anchors.fill: parent
            source: "file:///etc/quickshell-greeter/wallpaper.png"
            fillMode: Image.PreserveAspectCrop
            smooth: true
            cache: true
        }

        // Heavy dim — matches the lock screen.
        Rectangle {
            anchors.fill: parent
            color: Theme.dim
        }

        Column {
            id: stack
            anchors.centerIn: parent
            spacing: root.revealed ? 60 : 0

            Behavior on spacing {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            BigClock {
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Collapsing slot. Growing height pushes the Column down, which
            // (because Column is centerIn parent) shifts the whole stack
            // upward — visually lifting the clock to make room.
            Item {
                id: boxSlot
                anchors.horizontalCenter: parent.horizontalCenter
                // 360 box + 40px slack each side so the wrong-password shake
                // (LoginBox.shakeAnim, ±14px) isn't clipped at the box edges.
                width: 440
                height: root.revealed ? 180 : 0
                opacity: root.revealed ? 1 : 0
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                LoginBox {
                    id: loginBox
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Battery readout, top-right. greeter user can read sysfs (BAT0/uevent
        // is world-readable — same source the main shell's Battery.qml uses, no
        // upower dep). Declared before the blackout so it hides under it when
        // asleep. Plain "90%" fg text; "+" prefix while charging (Terminus-
        // safe glyphs only — no Nerd battery icon).
        Row {
            id: battery
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 8

            property int    capacity: 0
            property string status: ""

            Process {
                id: batRead
                command: ["cat", "/sys/class/power_supply/BAT0/uevent"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const lines = text.split('\n')
                        for (let i = 0; i < lines.length; ++i) {
                            const idx = lines[i].indexOf('=')
                            if (idx < 0) continue
                            const k = lines[i].substring(0, idx)
                            const v = lines[i].substring(idx + 1)
                            if (k === "POWER_SUPPLY_CAPACITY")    battery.capacity = parseInt(v)
                            else if (k === "POWER_SUPPLY_STATUS") battery.status   = v
                        }
                    }
                }
            }

            Timer {
                interval: 30000
                running: true; repeat: true; triggeredOnStart: true
                onTriggered: batRead.running = true
            }

            Text {
                text: (battery.status === "Charging" ? "+" : "") + battery.capacity + "%"
                color: battery.status === "Charging" ? Theme.accentSoft : Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
            }
        }

        // Asleep blackout — sits above wallpaper, dim, clock, and box.
        // awake=false → opaque black covers everything. First key/click
        // fades it (350ms) without revealing the box.
        Rectangle {
            id: blackout
            anchors.fill: parent
            color: "black"
            opacity: root.awake ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.revealed
            cursorShape: root.awake ? Qt.ArrowCursor : Qt.BlankCursor
            onClicked: {
                if (!root.awake) { root.wake(); return }
                root.reveal()
            }
        }

        Keys.onPressed: function (event) {
            if (root.handlePowerKey(event)) return
            if (!root.awake) {
                root.wake()
                event.accepted = true
                return
            }
            if (root.revealed) {
                // Forwarded by LoginBox's own keymap; just bump idle so the
                // user typing doesn't dim under them.
                idleTimer.restart()
                return
            }
            // Any key is a reveal-only trigger — it opens the box but is NOT
            // injected into the field (matches the lock screen). focusDelay →
            // loginBox.focusInitial() focuses the right field once the slot
            // opens, so the user always types their password from empty.
            root.reveal()
            event.accepted = true
        }

        // Reach back into the LoginBox once the slot has begun opening so the
        // field has focus even if the reveal was a click (no keystroke to
        // forward).
        Timer {
            id: focusDelay
            interval: 30
            repeat: false
            onTriggered: loginBox.focusInitial()
        }

        // Power keys (F1/F2/F5) — see root.handlePowerKey().
        Process { id: suspendProc;  command: ["systemctl", "suspend"];  running: false }
        Process { id: poweroffProc; command: ["systemctl", "poweroff"]; running: false }
        Process { id: rebootProc;   command: ["systemctl", "reboot"];   running: false }
    }
}
