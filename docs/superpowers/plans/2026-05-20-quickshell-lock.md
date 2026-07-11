# Quickshell screen locker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `swaylock` with a Quickshell-integrated screen locker that visually mirrors `quickshell-greeter` (Sky Paper palette, cream `> _` box, dim wallpaper).

**Architecture:** A `LockScreen` component added to the running user shell (`~/dotfiles/quickshell/.config/quickshell/`). Owns a single `WlSessionLock` (ext-session-lock-v1), one `WlSessionLockSurface` per screen, a shared `PamContext` (config `login`), and an `IpcHandler` exposing `lock()` / `unlock()` for external triggers. swayidle and niri call `qs ipc call lock lock`; the swaylock stow package is deleted.

**Tech Stack:** Quickshell (QML), `Quickshell.Wayland.WlSessionLock`, `Quickshell.Services.Pam.PamContext`, `Quickshell.Io.IpcHandler`, swayidle, niri, GNU stow.

**Spec:** `docs/superpowers/specs/2026-05-20-quickshell-lock-design.md`.

**Operating constraints (project memory):**
- Current branch `laniakea` is the laptop's main branch — work on a feature branch and merge only after live verification.
- `~/.config/quickshell` is a **directory symlink** into `~/dotfiles/quickshell/.config/quickshell/` — editing dotfiles directly affects the running shell via live reload.
- Live-reload QML edits validate cleanly. To validate a **fresh** `qs` startup, kill the running instance and clear the cache first (otherwise stale-cache errors are false positives).
- There are no automated tests for QML/dotfiles work; verification is manual via concrete shell commands shown in each task.

---

## File map

**Create:**
- `quickshell/.config/quickshell/LockScreen.qml` — top-level: `WlSessionLock` + per-screen surfaces + `PamContext` + `IpcHandler`.
- `quickshell/.config/quickshell/LockBox.qml` — the cream rectangle (hostname + password Field + status), with pop-in/pop-out animations.
- `quickshell/.config/quickshell/Field.qml` — copy of `quickshell-greeter/.config/quickshell-greeter/Field.qml` (`> _` prompt + TextInput).

**Modify:**
- `quickshell/.config/quickshell/shell.qml` — add `LockScreen {}` at the `Scope` root.
- `swayidle/.config/swayidle/config` — replace three `swaylock -f` invocations with `qs ipc call lock lock`.
- `swayidle/.config/swayidle/README.md` — update the timeline table and always-on hooks to reference the Quickshell locker.
- `niri/.config/niri/config.kdl` line 431 — rebind `Super+Alt+L` from `spawn "swaylock"` to `spawn "qs" "ipc" "call" "lock" "lock"`.
- `CONTEXT.md` — short status entry under the existing 2026-05-19 swayidle/swaylock block, noting the cutover.

**Delete:**
- `swaylock/` (entire stow package).

---

## Task 0: Create feature branch

**Files:** none.

- [ ] **Step 1: Confirm clean working tree**

Run: `git -C /home/aru/dotfiles status`
Expected: `nothing to commit, working tree clean` (the recent-commits list at session start shows the repo is clean).

- [ ] **Step 2: Confirm we are on `laniakea`**

Run: `git -C /home/aru/dotfiles branch --show-current`
Expected: `laniakea`

- [ ] **Step 3: Branch off**

Run:
```bash
git -C /home/aru/dotfiles checkout -b quickshell-lock
```
Expected: `Switched to a new branch 'quickshell-lock'`

- [ ] **Step 4: Verify**

Run: `git -C /home/aru/dotfiles branch --show-current`
Expected: `quickshell-lock`

No commit at this step — the branch is the commit boundary.

---

## Task 1: Copy `Field.qml` into the user shell

The greeter's `Field.qml` is the bare `> _` TextInput. The user shell doesn't have one yet, so copy it verbatim (greeter runs as a different unix user; sharing the file via symlink isn't possible — same reason `Theme.qml` is duplicated, per the comment in `quickshell-greeter/.config/quickshell-greeter/Theme.qml`).

**Files:**
- Create: `/home/aru/dotfiles/quickshell/.config/quickshell/Field.qml`
- Reference (read-only): `/home/aru/dotfiles/quickshell-greeter/.config/quickshell-greeter/Field.qml`

- [ ] **Step 1: Copy the file**

Run:
```bash
cp /home/aru/dotfiles/quickshell-greeter/.config/quickshell-greeter/Field.qml \
   /home/aru/dotfiles/quickshell/.config/quickshell/Field.qml
```

- [ ] **Step 2: Sanity-check it matches**

Run:
```bash
diff /home/aru/dotfiles/quickshell-greeter/.config/quickshell-greeter/Field.qml \
     /home/aru/dotfiles/quickshell/.config/quickshell/Field.qml
```
Expected: no output (files identical).

- [ ] **Step 3: Verify it parses in context**

The running `qs` should hot-reload but not yet use the file (nothing imports it). Confirm it didn't break anything:
```bash
pgrep -a qs    # running quickshell process should still be alive
```
Expected: one `qs` process (the running bar), unchanged.

- [ ] **Step 4: Commit**

```bash
git -C /home/aru/dotfiles add quickshell/.config/quickshell/Field.qml
git -C /home/aru/dotfiles commit -m "quickshell: copy Field.qml from greeter (lock prep)"
```

---

## Task 2: Write `LockBox.qml`

The cream-coloured rectangle: hostname strip + one password Field + status line, with pop-in/pop-out animations. Modeled on `quickshell-greeter/.config/quickshell-greeter/LoginBox.qml` but with a single field and no Greetd wiring (auth is driven from `LockScreen.qml`).

**Files:**
- Create: `/home/aru/dotfiles/quickshell/.config/quickshell/LockBox.qml`

- [ ] **Step 1: Write the file**

```qml
import QtQuick
import Quickshell

// Cream password box for the lock screen. Mirrors LoginBox in the greeter:
// same dimensions, same palette, same pop-in/pop-out animations, but with one
// field (password) and no Greetd wiring — PAM is driven from LockScreen.qml.
//
// State is pushed in by LockScreen via properties:
//   - active       : true → run appear animation, focus the field
//   - exiting      : true → run exit animation; signal `exited` on finish
//   - clearCounter : incrementing int → clear field + refocus (used on
//                    failed auth; counter pattern survives QML binding
//                    deduplication, which a bool toggle wouldn't).
Rectangle {
    id: box

    // Driven by LockScreen.qml.
    property string statusText: ""
    property color  statusColor: Theme.muted
    property bool   active: false
    property bool   exiting: false
    property int    clearCounter: 0
    property alias  passwordText: passInput.text

    signal submitted()    // user pressed Enter on the password field
    signal exited()       // exit animation finished

    width: 360
    height: 180
    radius: 0
    color: Theme.boxFill

    // Initial state — appearAnim runs these to 1.0 / 1.0 when active flips true.
    opacity: 0
    scale: 0.94
    transformOrigin: Item.Center

    onActiveChanged: {
        if (active) {
            // Reset to starting pose so re-locks animate cleanly.
            opacity = 0
            scale = 0.94
            exiting = false
            passInput.clear()
            appearAnim.start()
            passInput.forceActiveFocus()
        }
    }

    onExitingChanged: if (exiting) exitAnim.start()

    onClearCounterChanged: {
        passInput.clear()
        passInput.forceActiveFocus()
    }

    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: box; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: box; property: "scale";   to: 1.0; duration: 200; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: box; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: box; property: "scale";   to: 0.96; duration: 150; easing.type: Easing.InCubic }
        onFinished: box.exited()
    }

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: parent.width - 56

        // Hostname strip — matches the greeter.
        Text {
            width: parent.width
            text: "laniakea"
            color: Theme.muted
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }

        Field {
            id: passInput
            width: parent.width
            password: true
            textColor: Theme.fg
            onAccepted: box.submitted()
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: box.statusText
            color: box.statusColor
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }
    }
}
```

- [ ] **Step 2: Verify the running shell didn't break**

Quickshell live-reloads. The bar shouldn't change (nothing imports LockBox yet) but the process should still be alive and the QML log should be clean.

```bash
pgrep -a qs
```
Expected: one `qs` process running.

If you want to see live QML output, run `journalctl --user -fn 50 -u quickshell 2>/dev/null || pgrep -a qs` — or watch the terminal where you started `qs` if it's foregrounded.

- [ ] **Step 3: Commit**

```bash
git -C /home/aru/dotfiles add quickshell/.config/quickshell/LockBox.qml
git -C /home/aru/dotfiles commit -m "quickshell: LockBox.qml (cream password box, mirrors LoginBox)"
```

---

## Task 3: Write `LockScreen.qml`

The top-level component: WlSessionLock + per-screen surfaces + shared PamContext + IpcHandler. This is the only file that knows about ext-session-lock-v1 and PAM.

**Files:**
- Create: `/home/aru/dotfiles/quickshell/.config/quickshell/LockScreen.qml`

- [ ] **Step 1: Write the file**

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Session locker. Triggered by `qs ipc call lock lock`.
//
// Protocol: ext-session-lock-v1 (via WlSessionLock). When `sessionLock.locked
// = true` the compositor maps one surface per screen — anything below the
// surface (the desktop) is invisible until we set `locked = false`. If this
// process crashes while locked, the compositor keeps the screen blanked
// indefinitely; recovery is Ctrl+Alt+F2 → TTY → restart the session.
//
// Auth: PamContext with config "login" (stock on Arch). `user` is unset, so
// PAM uses the current user automatically. The conversation is driven by the
// pamMessage / responseRequired signals — same shape as the greeter's Greetd
// flow.
//
// Triggers: external callers do `qs ipc call lock lock`. swayidle's `lock`
// directive bridges `loginctl lock-session` to this same path, so anything
// that asks logind to lock still ends up here.
//
// Naming note: the WlSessionLock is `sessionLock`, not `lock`, because the
// IPC handler exposes a function named `lock()` and we don't want any
// shadowing ambiguity.
Scope {
    id: scope

    // ---- Shared state pushed into each LockBox ---------------------------

    property string  pendingPassword: ""
    property int     failedAttempts:  0
    property string  statusText:      ""
    property color   statusColor:     Theme.muted
    property bool    exiting:         false
    property int     clearCounter:    0

    // ---- Lock surface ----------------------------------------------------

    WlSessionLock {
        id: sessionLock
        locked: false

        // One WlSessionLockSurface per screen. Each is a fullscreen window
        // owned by the compositor; we paint wallpaper + dim + LockBox into it.
        WlSessionLockSurface {
            color: "black"   // protocol forbids transparent lock surfaces

            Item {
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: "file:///home/aru/Pictures/wallpapers/clouds.png"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.dim
                }

                LockBox {
                    anchors.centerIn: parent

                    active:       sessionLock.locked
                    exiting:      scope.exiting
                    clearCounter: scope.clearCounter
                    statusText:   scope.statusText
                    statusColor:  scope.statusColor

                    onSubmitted: scope.submit(passwordText)
                    onExited:    scope.dropLock()
                }
            }
        }
    }

    // ---- Auth ------------------------------------------------------------

    PamContext {
        id: pam
        config: "login"
        // `user` left unset → current user, per Quickshell docs.

        onPamMessage: {
            if (!responseRequired) return
            pam.respond(scope.pendingPassword)
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                scope.failedAttempts = 0
                scope.statusText = ""
                scope.beginExit()
            } else {
                scope.failedAttempts += 1
                const base = (pam.messageIsError && pam.message.length > 0)
                    ? pam.message
                    : "auth failed"
                scope.statusText = base + " — " + scope.failedAttempts
                scope.statusColor = Theme.warn
                scope.pendingPassword = ""
                scope.clearCounter += 1
                // Tear down the PAM session; the *next* submit() will start
                // a fresh one with the new password. (Re-arming PAM here
                // would immediately auto-respond with the now-empty
                // pendingPassword and loop the failure.)
                pam.active = false
            }
        }

        onError: function (err) {
            scope.statusText = "pam error"
            scope.statusColor = Theme.warn
        }
    }

    // ---- Helpers ---------------------------------------------------------

    // Start (or restart) the PAM conversation with the user's typed password.
    // Buffering the password before starting PAM is what makes auth "type-then-Enter"
    // instead of "PAM prompts → auto-respond empty → fail before you typed".
    function submit(password) {
        if (password.length === 0) return
        scope.pendingPassword = password
        if (pam.active) return   // a session is already running; let it complete
        pam.active = true        // starts the PAM conversation
    }

    // Auth succeeded → animate boxes out. dropLock() (below) actually
    // unmaps the surfaces once the animation finishes.
    function beginExit() {
        scope.exiting = true
    }

    // Called from LockBox.onExited. With multiple surfaces all animations
    // finish in lock-step (same duration); the first to fire drops the
    // lock and the rest become no-ops because sessionLock.locked is already
    // false.
    function dropLock() {
        if (!sessionLock.locked) return
        sessionLock.locked = false
        scope.pendingPassword = ""
        scope.exiting = false
        pam.active = false
        unlockProc.running = true   // sync logind state; idempotent
    }

    Process {
        id: unlockProc
        command: ["loginctl", "unlock-session"]
        running: false
    }

    // ---- IPC trigger -----------------------------------------------------

    IpcHandler {
        target: "lock"

        function lock(): void {
            if (sessionLock.locked) return
            scope.failedAttempts = 0
            scope.statusText = ""
            scope.statusColor = Theme.muted
            scope.pendingPassword = ""
            scope.exiting = false
            sessionLock.locked = true
            // PAM is NOT started here — the first submit() will start it
            // with a real password.
        }

        function unlock(): void {
            // Manual escape hatch (debugging). Skips PAM and the animation.
            scope.dropLock()
        }
    }
}
```

- [ ] **Step 2: Live-reload check**

Quickshell live-reloads on file change. The bar should still render and no parse error should hit the log. Confirm:
```bash
pgrep -a qs
```
Expected: one `qs` process still running.

- [ ] **Step 3: Verify IPC target is registered**

```bash
qs ipc show
```
Expected output includes:
```
target lock
  function lock(): void
  function unlock(): void
```

If `lock` is missing, the file didn't load — check the terminal where `qs` is running (or its journald output) for a QML error and fix before moving on.

- [ ] **Step 4: Commit**

```bash
git -C /home/aru/dotfiles add quickshell/.config/quickshell/LockScreen.qml
git -C /home/aru/dotfiles commit -m "quickshell: LockScreen.qml (WlSessionLock + PAM + IPC)"
```

---

## Task 4: Wire `LockScreen` into `shell.qml`

**Files:**
- Modify: `/home/aru/dotfiles/quickshell/.config/quickshell/shell.qml`

- [ ] **Step 1: Edit `shell.qml`**

Replace:
```qml
import Quickshell

// Entry point. Sky Paper bar for niri — see Theme.qml / PALETTE.md.
Scope {
    Bar {}
}
```

with:
```qml
import Quickshell

// Entry point. Sky Paper bar for niri — see Theme.qml / PALETTE.md.
// LockScreen is dormant until `qs ipc call lock lock` flips it on.
Scope {
    Bar {}
    LockScreen {}
}
```

- [ ] **Step 2: Verify `qs ipc show` still lists `lock`**

Run:
```bash
qs ipc show
```
Expected: `target lock` block with `lock()` and `unlock()` functions.

- [ ] **Step 3: Commit**

```bash
git -C /home/aru/dotfiles add quickshell/.config/quickshell/shell.qml
git -C /home/aru/dotfiles commit -m "quickshell: instantiate LockScreen in shell.qml"
```

---

## Task 5: First end-to-end lock test

The lock screen now exists. This is the high-risk step — keep a TTY ready.

**Files:** none.

- [ ] **Step 1: Prep an escape hatch**

Before testing, confirm you can switch to a TTY: press `Ctrl+Alt+F2`. You should see a text-mode login. Log in there (don't lock the GUI from inside the TTY). Switch back: `Ctrl+Alt+F1` (or whichever VT runs niri — `loginctl show-session $XDG_SESSION_ID | grep VTNr` to find it).

If the lock breaks, you can go back to F2, run `pkill niri` or `pkill -9 qs`, and recover.

- [ ] **Step 2: Trigger the lock**

In a graphical terminal:
```bash
qs ipc call lock lock
```
Expected: the screen dims, wallpaper appears, cream box pops in with `> ` prompt focused.

- [ ] **Step 3: Type your password and press Enter**

Expected: pop-out animation (150ms), desktop reappears, no flash of stale UI.

- [ ] **Step 4: Try a wrong password**

Run `qs ipc call lock lock`, type a wrong password, Enter.
Expected: status text `"auth failed — 1"` appears below the field in `Theme.warn` red. Field is cleared and refocused. A correct password on the next try unlocks (and `failedAttempts` resets to 0 next lock).

- [ ] **Step 5: Confirm `loginctl unlock-session` ran**

Run:
```bash
loginctl show-session $XDG_SESSION_ID | grep -E '^(LockedHint|State)='
```
Expected: `LockedHint=no` and `State=active`.

- [ ] **Step 6: Stuck? Recovery**

If the cream box doesn't appear but the screen is blanked, switch to F2 and run:
```bash
pkill -9 qs    # forces compositor to release the lock client
```
Diagnose by reading the journal:
```bash
journalctl --user --since "5 min ago" | grep -iE 'qml|quickshell|pam'
```
Common causes: PAM config name wrong (try `system-local-login`), missing `Quickshell.Services.Pam` import, typo'd property.

- [ ] **Step 7: Commit if a fix was needed**

Only commit if Step 6 led to a code change. Use a descriptive message, e.g. `quickshell: fix PAM config name for lock`.

---

## Task 6: Update swayidle config

**Files:**
- Modify: `/home/aru/dotfiles/swayidle/.config/swayidle/config`

- [ ] **Step 1: Replace the three `swaylock -f` invocations**

The current file (lines 12, 16, 23, 26 according to the spec's read) has `swaylock -f` in three places: the 10m timeout (which also chains a niri DPMS command), the `before-sleep` hook, and the `lock` hook. Replace every `swaylock -f` with `qs ipc call lock lock`. The 10m line keeps the `; niri msg action power-off-monitors` chain.

Use Edit on these three lines (each is on one physical line — backslash continuation is forbidden in swayidle, per the existing README's gotcha section).

Line 16 — change:
```
timeout 600 'swaylock -f; niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'
```
to:
```
timeout 600 'qs ipc call lock lock; niri msg action power-off-monitors' resume 'niri msg action power-on-monitors'
```

Line 23 — change:
```
before-sleep 'swaylock -f'
```
to:
```
before-sleep 'qs ipc call lock lock'
```

Line 26 — change:
```
lock 'swaylock -f'
```
to:
```
lock 'qs ipc call lock lock'
```

- [ ] **Step 2: Update the file comment header**

The top of the file says swayidle spawns swaylock — adjust the comments to mention Quickshell instead. Specifically the `# 10m — lock first (overlay paint), then DPMS off in the same step.` comment is fine, but lines that mention swaylock by name should now say "Quickshell lock" or "`qs ipc call lock lock`".

- [ ] **Step 3: Parse-validate the config**

Quickshell-side IPC is reached by an external command, so this is purely a swayidle syntax check:
```bash
swayidle -w -C /home/aru/dotfiles/swayidle/.config/swayidle/config &
SWAYIDLE_TEST_PID=$!
sleep 1
kill $SWAYIDLE_TEST_PID
```
Expected: no `wordexp syntax error` and no exit before the `kill`. If swayidle exited on its own before the kill, re-read the file — most likely a stray backslash.

(Note: we cannot run a second swayidle alongside the one niri spawned. The command above launches it in the foreground and kills it immediately, just to parse-check.)

- [ ] **Step 4: Restart the live swayidle**

The niri-spawned swayidle is still running the old config. Kill it; niri will respawn it (because of `spawn-at-startup`):
```bash
pkill swayidle
sleep 1
pgrep -a swayidle
```
Expected: a fresh `swayidle -w` process owned by your user. If nothing came back, niri may not have respawned — run `niri msg action spawn -- swayidle -w` or check the niri config's `spawn-at-startup` line.

- [ ] **Step 5: Trigger via `loginctl lock-session`**

This validates the most important path — anything that asks logind to lock should still work:
```bash
loginctl lock-session
```
Expected: lock screen appears (logind broadcasts `Lock` → swayidle's `lock` handler runs `qs ipc call lock lock` → LockScreen activates). Unlock with your password.

- [ ] **Step 6: Commit**

```bash
git -C /home/aru/dotfiles add swayidle/.config/swayidle/config
git -C /home/aru/dotfiles commit -m "swayidle: switch lock trigger from swaylock to qs ipc"
```

---

## Task 7: Update niri keybind

**Files:**
- Modify: `/home/aru/dotfiles/niri/.config/niri/config.kdl` line 431

- [ ] **Step 1: Edit the keybind**

Change:
```kdl
    Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }
```
to:
```kdl
    Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "qs" "ipc" "call" "lock" "lock"; }
```

- [ ] **Step 2: Reload niri config**

niri reloads on save automatically if `prefer-no-csd` etc. are unchanged; for keybinds, a manual reload is safe:
```bash
niri msg action reload-config
```
Expected: no error in the niri output. The hotkey overlay (`Super+Shift+/`) should now list "Lock the Screen" instead of "Lock the Screen: swaylock".

- [ ] **Step 3: Test the keybind**

Press `Super+Alt+L`.
Expected: lock screen appears. Unlock with your password.

- [ ] **Step 4: Commit**

```bash
git -C /home/aru/dotfiles add niri/.config/niri/config.kdl
git -C /home/aru/dotfiles commit -m "niri: rebind Super+Alt+L from swaylock to qs ipc"
```

---

## Task 8: Update swayidle README

**Files:**
- Modify: `/home/aru/dotfiles/swayidle/.config/swayidle/README.md`

- [ ] **Step 1: Update the timeline table**

The table currently shows `swaylock -f` in the 10-min row and the always-on hooks (`before-sleep` and `lock`). Replace every occurrence of `swaylock -f` with `qs ipc call lock lock`. Update the prose around the table that says "lock paints first so there's no bare-desktop frame" — same wording is fine, but the bridge claim (`loginctl lock-session → swaylock`) becomes `loginctl lock-session → swayidle's lock handler → qs ipc call lock lock → Quickshell LockScreen`.

- [ ] **Step 2: Drop the swaylock-specific reference**

Remove (or rewrite) any line that points at `../swaylock/README.md` — that file is going away in Task 9. Replace with a pointer to the LockScreen.qml file in the quickshell package, e.g. `~/.config/quickshell/LockScreen.qml`.

- [ ] **Step 3: Commit**

```bash
git -C /home/aru/dotfiles add swayidle/.config/swayidle/README.md
git -C /home/aru/dotfiles commit -m "swayidle: README — point at Quickshell locker, drop swaylock refs"
```

---

## Task 9: Delete the swaylock stow package

**Files:**
- Delete: `/home/aru/dotfiles/swaylock/` (entire directory)
- Verify: `/home/aru/.config/swaylock` (symlink will dangle until you remove it)

- [ ] **Step 1: Confirm nothing else references swaylock**

Run:
```bash
grep -rn 'swaylock' /home/aru/dotfiles \
    --exclude-dir=docs \
    --exclude-dir=.git
```
Expected: only matches inside README/comment text that we'll update in this task, or zero matches. If anything in active config (niri, swayidle, fish, quickshell QML) still references swaylock, fix it before deleting.

- [ ] **Step 2: Remove the dangling symlink from ~/.config**

```bash
ls -la /home/aru/.config/swaylock
```
Expected: `lrwxrwxrwx ... /home/aru/.config/swaylock -> ../dotfiles/swaylock/.config/swaylock`

Remove the symlink only (it's safe because it's a *file*-typed symlink, not a directory symlink — `ls -la` shows it as `lrwxrwxrwx`):
```bash
rm /home/aru/.config/swaylock
```

- [ ] **Step 3: Delete the stow package**

```bash
rm -rf /home/aru/dotfiles/swaylock
```

- [ ] **Step 4: Verify**

```bash
ls /home/aru/dotfiles/swaylock 2>&1
ls /home/aru/.config/swaylock  2>&1
```
Expected: both `No such file or directory`.

- [ ] **Step 5: Verify the swaylock *binary* is still on the system**

(We are not pacman-removing it — only deleting dotfiles.)
```bash
command -v swaylock
```
Expected: `/usr/bin/swaylock` (still installed). This is intentional: keeping the binary costs nothing and gives a manual fallback if anything goes sideways later.

- [ ] **Step 6: Commit**

```bash
git -C /home/aru/dotfiles add -A swaylock
git -C /home/aru/dotfiles commit -m "swaylock: delete stow package (replaced by Quickshell lock)"
```
(`git add -A swaylock` stages the deletion of the directory.)

---

## Task 10: Full verification

End-to-end check across every trigger path the spec calls out.

**Files:** none.

- [ ] **Step 1: Manual lock via IPC**

```bash
qs ipc call lock lock
```
Expected: cream box appears centered on every connected screen. Wrong password shows `"auth failed — 1"`. Correct password unlocks.

- [ ] **Step 2: Manual lock via logind**

```bash
loginctl lock-session
```
Expected: same as Step 1 (logind → swayidle bridge → IPC).

- [ ] **Step 3: niri keybind**

Press `Super+Alt+L`.
Expected: same as Step 1.

- [ ] **Step 4: Idle 10-min path (shortened)**

Run a foreground swayidle with a 30-second override (do NOT pkill the live swayidle for this; just spawn a parallel one in foreground for the test). Open a terminal and run:
```bash
swayidle -w timeout 30 'qs ipc call lock lock; niri msg action power-off-monitors' \
                       resume 'niri msg action power-on-monitors'
```
Don't touch the keyboard or mouse for 30 seconds.
Expected: lock screen appears, then a few seconds later the screen powers off. Mouse-move re-enables the screen — the lock remains visible. Unlock with password. Ctrl-C the test swayidle.

- [ ] **Step 5: Suspend / resume**

```bash
systemctl suspend
```
Expected: laptop suspends. On resume (lid open + power button), the lock screen is already visible (no flash of the desktop). Unlock with password.

- [ ] **Step 6: `qs ipc show` smoke test**

```bash
qs ipc show
```
Expected: `target lock` block with `lock(): void` and `unlock(): void`. (Sanity check that nothing got nuked by a previous step.)

- [ ] **Step 7: Multi-monitor (if applicable)**

If an external monitor is available, plug it in while locked.
Expected: a second cream box appears on the new screen. Unlock works.

If you don't have a second monitor handy, skip — laniakea is the laptop and this is a single-display verification by default.

- [ ] **Step 8: Idle-cost sanity check**

Confirm the integration didn't bloat the running shell:
```bash
ps -o rss,cmd -C qs
```
Expected: a single process with RSS in the same ballpark as before (typically ~70–120 MB on this hardware). Tens of MB above prior baseline warrants a look but is not a blocker.

No commit at this step — verification only.

---

## Task 11: Update CONTEXT.md and merge

**Files:**
- Modify: `/home/aru/dotfiles/CONTEXT.md`

- [ ] **Step 1: Add a session block**

Append a short session block under the existing 2026-05-19 swayidle/swaylock entry. Mirror the existing prose style (mixed Russian/English is fine, follow the surrounding convention). Example outline:

```markdown
## 🔒 Session 2026-05-20 — Quickshell lock screen

Swaylock заменён на Quickshell-локер (`LockScreen.qml`):

- `WlSessionLock` (ext-session-lock-v1) + `PamContext` (config `login`) + `IpcHandler` (`qs ipc call lock lock`).
- Визуально — клон greeter'а: тот же `clouds.png`, dim, кремовый box `> _`, hostname-strip, pop-in/out.
- Триггеры переключены: swayidle (3 места) и niri `Super+Alt+L` → `qs ipc call lock lock`. `loginctl lock-session` работает транзитно через swayidle's `lock`-хук.
- `~/dotfiles/swaylock/` снесён. Бинарь `swaylock` оставлен в системе на всякий случай.
- Верифицировано: ручной IPC, `loginctl lock-session`, keybind, 30s-idle override, `systemctl suspend`.
```

(Adjust wording to match the user's CONTEXT.md voice — this is a starter outline.)

- [ ] **Step 2: Commit**

```bash
git -C /home/aru/dotfiles add CONTEXT.md
git -C /home/aru/dotfiles commit -m "CONTEXT: 2026-05-20 quickshell lock cutover"
```

- [ ] **Step 3: Merge to `laniakea`**

Only after all of Task 10 passed live:
```bash
git -C /home/aru/dotfiles checkout laniakea
git -C /home/aru/dotfiles merge --no-ff quickshell-lock -m "merge: Quickshell screen locker (replaces swaylock)"
```

- [ ] **Step 4: Verify on `laniakea`**

```bash
git -C /home/aru/dotfiles log --oneline -10
git -C /home/aru/dotfiles status
```
Expected: clean tree on `laniakea`, the merge commit + the feature branch's commits visible in the log.

- [ ] **Step 5: Delete the feature branch (optional)**

```bash
git -C /home/aru/dotfiles branch -d quickshell-lock
```
Expected: `Deleted branch quickshell-lock`. Refuses with `-d` if anything is unmerged — that's the safety net.

---

## What this plan does not cover

- Lock-screen clock / media controls (excluded by the spec).
- Replacing the swaylock pacman package (intentionally kept; spec §non-goals).
- Adapting the design for the desktop sibling machine (`celestia`) — separate effort if/when the time comes.
