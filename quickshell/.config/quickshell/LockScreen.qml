import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Session locker. Triggered by `qs ipc call lock lock`.
//
// Visual model — three stages, two flags (awake, revealed):
//   1. awake      awake=true,  revealed=false → dim wallpaper + big HH:MM
//      clock visible. Default on lock (no black flash).
//   2. revealed   awake=true,  revealed=true  → slot under the clock grows
//      to 180px; Column { anchors.centerIn: parent } re-centers, pushing
//      the clock upward to make room for the LockBox.
//   3. asleep     awake=false → full black overlay covers everything. Only
//      entered after `idleTimer` (10 min, no key/click) to save power; any
//      key/click wakes back to the clock.
//
// Input gating:
//   - asleep      → any key/click only wakes (no reveal).
//   - awake       → any key (except Esc) / click reveals an EMPTY box and
//                   focuses the field; the summoning key is not injected.
//   - revealed    → keys go to the password field; Esc collapses back to awake
//                   and clears the field.
//
// Protocol: ext-session-lock-v1 (via WlSessionLock). When `sessionLock.locked
// = true` the compositor maps one surface per screen — anything below the
// surface is invisible until we set `locked = false`. If this process crashes
// while locked, the compositor keeps the screen blanked indefinitely; recovery
// is Ctrl+Alt+F2 → TTY → restart the session.
//
// Auth: PamContext with config "login" (stock on Arch). `user` is unset, so
// PAM uses the current user automatically. We buffer the typed password and
// drive the conversation from the pamMessage signal (same shape as the
// greeter's Greetd flow).
Scope {
    id: scope

    // Shared across all surfaces.
    property string pendingPassword: ""
    property int    failedAttempts:  0
    property string statusText:      ""
    property color  statusColor:     Theme.muted
    property bool   awake:           true    // false → black overlay over everything
    property bool   revealed:        false

    // Lock shows the clock immediately; after 10 min idle it falls back to
    // black (awake=false) to save power. Any key/click wakes via wake().
    Timer {
        id: idleTimer
        interval: 600 * 1000
        repeat: false
        running: false
        onTriggered: scope.awake = false
    }
    property int    clearCounter:    0   // increment → all LockBoxes clear+focus
    property int    shakeCounter:    0   // increment → all LockBoxes shake (wrong pw)

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surface
            color: "black"

            Item {
                id: surfaceRoot
                anchors.fill: parent
                focus: true
                // While true the summoning key is still held: focus stays on the
                // surface (not the field) so the key — and any autorepeat of it —
                // can never be typed. Cleared on its KeyRelease, which is when the
                // field finally gets focus.
                property bool armed: false
                // Guarantee the clock surface owns keyboard focus on map, so the
                // first key reaches Keys.onPressed and reveals the box.
                Component.onCompleted: forceActiveFocus()

                Image {
                    anchors.fill: parent
                    source: "file:///home/segfault/Pictures/wallpapers/mntvagaflexoki.png"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: true
                }

                // Heavy dim — wallpaper visible at ~15%.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.dim
                }

                Column {
                    id: stack
                    anchors.centerIn: parent
                    spacing: scope.revealed ? 60 : 0

                    Behavior on spacing {
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }

                    LockClock {
                        id: lockClock
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Collapsing slot. Height drives the "push": when revealed,
                    // it grows to 180 and the Column re-centers, lifting clock.
                    Item {
                        id: boxSlot
                        anchors.horizontalCenter: parent.horizontalCenter
                        // 360 box + 40px slack each side so the wrong-password
                        // shake (LockBox.shakeAnim, ±14px) isn't clipped.
                        width: 440
                        height: scope.revealed ? 180 : 0
                        opacity: scope.revealed ? 1 : 0
                        clip: true

                        Behavior on height {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        LockBox {
                            id: box
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            statusText: scope.statusText
                            statusColor: scope.statusColor
                        }

                        Connections {
                            target: box
                            function onSubmitted() { scope.submit(box.passwordText) }
                        }

                        // Wrong-password shake broadcast from the scope.
                        Connections {
                            target: scope
                            function onShakeCounterChanged() { box.shake() }
                        }

                        // Broadcast clears from the scope.
                        Connections {
                            target: scope
                            function onClearCounterChanged() {
                                box.clear()
                                // Field keeps focus while revealed (retry after a
                                // failed attempt); otherwise focus returns to the
                                // clock surface so the next key can summon the box.
                                if (scope.revealed) box.focusField()
                                else surfaceRoot.forceActiveFocus()
                            }
                        }
                    }
                }

                // (battery readout removed — celestia is a desktop, no BAT0)

                // Top-right corner cluster — mirrors the bar's [language] [λ]
                // (Bar.qml), which is hidden beneath the lock surface while
                // locked. Same cells, same 9px inset, same top strip → lands in
                // the exact bar pixels. Painted BEFORE `blackout` so it vanishes
                // with everything else when the screen sleeps. The reveal
                // MouseArea sits above it, so the language cell shows + blinks on
                // change but isn't click-to-switch here (no accidental flips).
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    spacing: 0

                    Language {}

                    // Decorative λ. The bar's glyph toggles the control-center,
                    // but that layer lives below the lock surface — dead here — so
                    // this is a stripped, inert copy: accent glyph, no MouseArea,
                    // no cc/host wiring. Pure visual symmetry with the desktop.
                    Rectangle {
                        height: Theme.barHeight
                        width: Theme.cellSize
                        radius: 0
                        color: "transparent"

                        Text {
                            x: Math.round((parent.width - width) / 2)
                            y: Math.round((parent.height - height) / 2)
                            renderType: Text.NativeRendering
                            font.hintingPreference: Font.PreferFullHinting
                            text: "λ"
                            color: Theme.accentText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }

                // Asleep blackout. Sits above wallpaper, dim, and clock —
                // when scope.awake is false, the screen is fully black; the
                // first key/click fades it out (350ms) to reveal the dim
                // wallpaper + clock. Pointer events through (we want the
                // MouseArea below to receive clicks).
                Rectangle {
                    id: blackout
                    anchors.fill: parent
                    color: "black"
                    opacity: scope.awake ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !scope.revealed
                    cursorShape: scope.awake ? Qt.ArrowCursor : Qt.BlankCursor
                    onClicked: {
                        if (!scope.awake) { scope.wake(); return }
                        scope.reveal()
                        focusDelay.restart()   // click has no KeyRelease; focus via timer
                    }
                }

                Keys.onPressed: function (event) {
                    if (scope.handlePowerKey(event)) return
                    if (!scope.awake) {
                        scope.wake()
                        event.accepted = true
                        return
                    }
                    if (!scope.revealed) {
                        // Summon the empty box only on a key that produces TEXT
                        // (event.text non-empty). The field is NOT focused yet —
                        // that waits for this key's release (onReleased) so neither
                        // the key nor its autorepeat can be injected. Password blank.
                        //
                        // The text gate is what keeps the layout toggle from popping
                        // the box: it's Alt+Shift (niri xkb grp:alt_shift_toggle), and
                        // niri delivers the switch as bare modifiers / an ISO_Next_Group
                        // keysym — none of which carry text. Enumerating Qt.Key_* was
                        // fragile (the toggle keysym isn't Alt/Shift); "does it type a
                        // character" is the real question, and a password key always does.
                        // Esc carries a text byte, so it needs its own no-op check.
                        if (event.key === Qt.Key_Escape || event.text.length === 0) {
                            event.accepted = true
                            return
                        }
                        scope.reveal()
                        surfaceRoot.armed = true
                        armBackstop.restart()
                        event.accepted = true
                        return
                    }
                    // Revealed but summon key still held → swallow its autorepeat
                    // (field isn't focused until release).
                    if (surfaceRoot.armed) {
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        scope.hideBox()
                        event.accepted = true
                    }
                }

                // Summon key released → now it's safe to focus the field; nothing
                // more from that keypress can land in it.
                Keys.onReleased: function (event) {
                    if (surfaceRoot.armed && scope.revealed) {
                        armBackstop.stop()
                        surfaceRoot.armed = false
                        box.focusField()
                        event.accepted = true
                    }
                }

                // Lockout safety: if the summon key's release never arrives
                // (focus stays armed → every key swallowed → box un-typeable),
                // focus anyway after 800ms. A normal tap releases first and
                // cancels this.
                Timer {
                    id: armBackstop
                    interval: 800
                    repeat: false
                    onTriggered: {
                        if (surfaceRoot.armed) {
                            surfaceRoot.armed = false
                            box.focusField()
                        }
                    }
                }

                Connections {
                    target: scope
                    function onRevealedChanged() {
                        // Collapsing back to the clock: disarm and reclaim focus so
                        // the next key summons cleanly. (Reveal focuses via release
                        // or, for clicks, focusDelay.)
                        if (!scope.revealed) {
                            armBackstop.stop()
                            surfaceRoot.armed = false
                            surfaceRoot.forceActiveFocus()
                        }
                    }
                }

                Timer {
                    id: focusDelay
                    interval: 30
                    repeat: false
                    onTriggered: box.focusField()
                }
            }
        }
    }

    PamContext {
        id: pam
        config: "login"
        // user left unset → current user.

        onPamMessage: {
            if (!pam.responseRequired) return
            pam.respond(scope.pendingPassword)
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                scope.failedAttempts = 0
                scope.statusText = ""
                scope.dropLock()
            } else {
                // PAM's message is usually blank or terse; show a clear line
                // of our own with the running attempt count, and shake the box.
                scope.failedAttempts += 1
                scope.statusText = "incorrect password — " + scope.failedAttempts
                scope.statusColor = Theme.warn
                scope.shakeCounter += 1
                scope.pendingPassword = ""
                scope.clearCounter += 1
                // Tear down PAM; next submit() will start a fresh session.
                pam.active = false
            }
        }

        onError: function (err) {
            scope.statusText = "pam error"
            scope.statusColor = Theme.warn
        }
    }

    function wake() { scope.awake = true; idleTimer.restart(); lockClock.refresh() }

    function reveal() { scope.revealed = true; idleTimer.restart() }

    // Power keys, live in every state (asleep / clock / revealed):
    //   F2 → power off, F5 → reboot. No suspend key — this desktop deliberately
    //   never suspends (see swayidle). The locked session is still the active
    //   session, so polkit's allow_active grants poweroff/reboot without a password.
    function handlePowerKey(event) {
        if (event.key === Qt.Key_F2)      { poweroffProc.running = true; event.accepted = true; return true }
        else if (event.key === Qt.Key_F5) { rebootProc.running   = true; event.accepted = true; return true }
        return false
    }

    function hideBox() {
        scope.revealed = false
        scope.pendingPassword = ""
        scope.statusText = ""
        scope.clearCounter += 1
    }

    function submit(password) {
        if (password.length === 0) return
        scope.pendingPassword = password
        if (pam.active) return
        pam.active = true
    }

    function dropLock() {
        if (!sessionLock.locked) return
        sessionLock.locked = false
        scope.pendingPassword = ""
        scope.revealed = false
        scope.awake = false
        scope.statusText = ""
        scope.clearCounter += 1
        pam.active = false
        idleTimer.stop()
        unlockProc.running = true   // sync logind state; idempotent
    }

    Process {
        id: unlockProc
        command: ["loginctl", "unlock-session"]
        running: false
    }

    // Force English (US) on lock so the password is never typed in ru/ua.
    // Index 0 = English (US) in niri's "us,ru,ua" layout list.
    Process {
        id: engLayoutProc
        command: ["niri", "msg", "action", "switch-layout", "0"]
        running: false
    }

    // Power keys (F2/F5) — see scope.handlePowerKey().
    Process { id: poweroffProc; command: ["systemctl", "poweroff"]; running: false }
    Process { id: rebootProc;   command: ["systemctl", "reboot"];   running: false }

    IpcHandler {
        target: "lock"

        function lock(): void {
            if (sessionLock.locked) return
            scope.failedAttempts = 0
            scope.statusText = ""
            scope.statusColor = Theme.muted
            scope.pendingPassword = ""
            scope.revealed = false
            scope.awake = true
            scope.clearCounter += 1
            idleTimer.restart()
            engLayoutProc.running = true   // password field always English
            sessionLock.locked = true
        }

        function unlock(): void {
            // Manual escape hatch (debugging). Skips PAM.
            scope.dropLock()
        }
    }
}
