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
        idleTimer.restart()
        // Focus is NOT taken here — a key-reveal focuses on the summon key's
        // release (onReleased), a click-reveal via focusDelay. This keeps the
        // summoning key (and its autorepeat) out of the field.
    }

    // Power keys, live in every state (asleep / clock / revealed):
    //   F2 → power off, F5 → reboot. No suspend key — this desktop deliberately
    //   never suspends (see swayidle), same as the user-shell LockScreen.
    // greetd's session is the active session on seat0/vt1, so polkit's
    // allow_active grants poweroff/reboot without a password.
    function handlePowerKey(event) {
        if (event.key === Qt.Key_F2)      { poweroffProc.running = true; event.accepted = true; return true }
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
        // True while the summoning key is held: focus stays here (not the field)
        // so the key and its autorepeat can't be typed. Cleared on its release.
        property bool armed: false

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

        // (battery readout removed — celestia is a desktop, no BAT0)

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
                focusDelay.restart()   // click has no KeyRelease; focus via timer
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
                // Summon key still held → swallow its autorepeat (field not
                // focused until release).
                if (surface.armed) { event.accepted = true; return }
                // Field owns focus now; just bump idle so typing doesn't dim.
                idleTimer.restart()
                return
            }
            // First key reveals the box but is NOT injected — the field is
            // focused only on this key's release (onReleased), so neither it nor
            // its autorepeat lands in the field. Password always starts empty.
            root.reveal()
            surface.armed = true
            armBackstop.restart()
            event.accepted = true
        }

        // Summon key released → safe to focus the field now.
        Keys.onReleased: function (event) {
            if (surface.armed && root.revealed) {
                armBackstop.stop()
                surface.armed = false
                loginBox.focusInitial()
                event.accepted = true
            }
        }

        // Lockout safety: if the summon key's release never arrives, focus the
        // field anyway after 800ms so login can't get stuck. A normal tap
        // releases first and cancels this.
        Timer {
            id: armBackstop
            interval: 800
            repeat: false
            onTriggered: {
                if (surface.armed) {
                    surface.armed = false
                    loginBox.focusInitial()
                }
            }
        }

        // Focus path for a CLICK reveal (no keystroke to release). Focuses the
        // right field once the slot has begun opening.
        Timer {
            id: focusDelay
            interval: 30
            repeat: false
            onTriggered: loginBox.focusInitial()
        }

        // Power keys (F2/F5) — see root.handlePowerKey().
        Process { id: poweroffProc; command: ["systemctl", "poweroff"]; running: false }
        Process { id: rebootProc;   command: ["systemctl", "reboot"];   running: false }
    }
}
