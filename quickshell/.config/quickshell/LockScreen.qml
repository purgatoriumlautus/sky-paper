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
                // Guarantee the clock surface owns keyboard focus on map, so the
                // first key reaches Keys.onPressed and reveals the box.
                Component.onCompleted: forceActiveFocus()

                Image {
                    anchors.fill: parent
                    source: "file:///home/segfault/Pictures/wallpapers/clouds.png"
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

                // Battery readout, top-right. Mirrors the greeter's: reads the
                // world-readable BAT0/uevent via cat (no upower dep), cream text
                // with a "+" prefix while charging (Terminus-safe glyphs only).
                // Declared before the blackout so it hides under it when asleep.
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
                    }
                }

                Keys.onPressed: function (event) {
                    if (!scope.awake) {
                        scope.wake()
                        event.accepted = true
                        return
                    }
                    if (!scope.revealed) {
                        // Esc on the clock is a no-op; any other key summons the
                        // empty box and hands focus to the field. The summoning
                        // key is NOT injected — the password starts blank.
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true
                            return
                        }
                        scope.reveal()
                        box.focusField()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        scope.hideBox()
                        event.accepted = true
                    }
                }

                // When the slot finishes opening, make sure the field has focus.
                Connections {
                    target: scope
                    function onRevealedChanged() {
                        if (scope.revealed) focusDelay.restart()
                        else surfaceRoot.forceActiveFocus()
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
            sessionLock.locked = true
        }

        function unlock(): void {
            // Manual escape hatch (debugging). Skips PAM.
            scope.dropLock()
        }
    }
}
