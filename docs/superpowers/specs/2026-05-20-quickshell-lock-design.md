# Quickshell screen locker (replace swaylock)

**Date:** 2026-05-20
**Status:** Design approved, ready for implementation plan.

## Goal

Replace `swaylock` with a session locker built into the running Quickshell
instance. Visual parity with `quickshell-greeter` (Sky Paper palette, clouds
wallpaper, dimmed overlay, cream `> _` box) so lock and login look like one
surface.

## Why

The current swaylock config matches the greeter's colours by hand but not its
typography, layout, or animations. The cream box, hostname strip, `> _`
prompt, pop-in animation, and warn-coloured status line are greeter-only — the
swaylock binary can't reproduce them. A QML-based locker can.

## Non-goals

- Clock / date / media controls on the lock screen.
- Lock-screen notifications.
- Per-monitor differentiation (all screens get the same surface).
- AC vs. battery behavioural differences (deliberately kept uniform — see
  `swayidle/README.md`).
- Replacing swaylock the **binary** on the system. We delete the dotfiles
  stow package and stop invoking the binary; pacman ownership is unchanged.

## Architecture

Single new top-level component `LockScreen.qml` added to the running shell at
`~/dotfiles/quickshell/.config/quickshell/`. Instantiated once from `shell.qml`
as a sibling of `Bar` and `ControlCenter`.

### Components inside `LockScreen.qml`

- `WlSessionLock { id: lock }` — the ext-session-lock-v1 client. Dormant
  (`locked: false`) when idle; flipping `locked = true` is what causes the
  compositor to map the lock surfaces.
- `WlSessionLockSurface` (one per screen, via the standard Quickshell
  `Variants { model: Quickshell.screens }` shape). Each surface contains the
  wallpaper, dim overlay, and a centered `LockBox`.
- `PamContext { id: pam; config: "login" }` — shared across surfaces (auth
  state is global, not per-screen). `user` is left unset so PAM uses the
  current user automatically (per Quickshell docs).
- `IpcHandler { target: "lock" }` exposing `lock()` and `unlock()` functions.
  External callers (swayidle / niri / manual) trigger the lock by running
  `qs ipc call lock lock`. This is Quickshell's first-class IPC pattern and
  is simpler than wiring a logind DBus listener inside QML.

### Files (final tree)

```
quickshell/.config/quickshell/
  LockScreen.qml          (new — owns WlSessionLock + PamContext + DBus listener)
  LockBox.qml             (new — cream rectangle, password field, status line)
  Field.qml               (new — copy of greeter's Field.qml: bare TextInput with `> _`)
  Theme.qml               (existing — already mirrors the greeter palette; reused as-is)
  shell.qml               (edit — add `LockScreen {}` at the Scope root)
  ...
```

`Field.qml` is a third copy of the same QML file (greeter has one, user shell
will now have one, and the system shell has none) — this is consistent with
the existing duplication of `Theme.qml` and is required because the greeter
runs as a different unix user that can't read `/home/aru`.

## Visual spec

Identical surface stack to `Greeter.qml`:

```
WlSessionLockSurface (fullscreen, per screen)
├── Image       source: file://~/Pictures/wallpapers/clouds.png
│               fillMode: PreserveAspectCrop
├── Rectangle   color: Theme.dim          (#80000000, same as greeter)
└── LockBox     anchors.centerIn: parent
```

`LockBox` mirrors `LoginBox` with one field instead of two:

- `width: 360`, `height: 180`, `radius: 0`, `color: Theme.boxFill`
  (`#B3F0EBE0`).
- Pop-in animation on `locked` going false→true: parallel opacity 0→1 +
  scale 0.94→1, 200 ms, `OutCubic`.
- Pop-out on unlock: parallel opacity 1→0 + scale 1→0.96, 150 ms, `InCubic`,
  then `lock.locked = false` on `finished`.
- Column layout, `spacing: 22`, `width: parent.width - 56`:
  1. Hostname strip — `"laniakea"`, `Theme.muted`, centered, `fontSize - 2`.
  2. `Field { password: true; textColor: Theme.fg }` — auto-focused.
  3. Status `Text` — `visible: text.length > 0`, centered, `fontSize - 2`,
     colour swaps between `Theme.muted` and `Theme.warn` (`#9C5450`).

Failed-attempt counter is shown inline in the status line (e.g.
`"auth failed — 2"`), matching the spirit of swaylock's
`show-failed-attempts`. Counter resets to 0 on every successful auth.

## Control flow

### Locking

```
swayidle 10m / before-sleep / lock  ─┐
niri Super+Alt+L                     ├──► qs ipc call lock lock
manual lock command                  ─┘            │
                                                   ▼
                                IpcHandler.lock() in LockScreen.qml:
                                    lock.locked = true
                                    pam.active   = true
                                                   │
                                                   ▼
                                Compositor maps lock surfaces
                                Password field receives focus
                                appearAnim runs
```

`loginctl lock-session` from outside callers still works **transitively**:
logind broadcasts the `Lock` signal, swayidle's `lock` handler receives it
and runs `qs ipc call lock lock`. swayidle is the bridge — no DBus code in
QML.

### Unlocking

```
type password + Enter
        ▼
PamContext drives the conversation:
  pam.onPamMessage → if pam.responseRequired: pam.respond(passwordInput.text)
        ▼
pam.onCompleted(PamResult.Success):
  exitAnim.start()              (150ms pop-out)
        ▼
exitAnim.onFinished:
  lock.locked = false           (compositor unmaps surfaces)
  Process { exec: ["loginctl", "unlock-session"] }  (sync logind state;
                                                     idempotent if already
                                                     unlocked)
        ▼
desktop visible, session resumed
```

### Failure

`pam.onCompleted(PamResult.Failed | PamResult.Error)`:

- `status.text = pam.messageIsError && pam.message ? pam.message : "auth failed"`
- `status.color = Theme.warn`
- `failedAttempts += 1`; append `" — <n>"` to status text.
- Clear password field, refocus, restart PAM with `pam.active = true` (the
  context goes inactive on completion).

## Trigger surface changes

### `swayidle/.config/swayidle/config`

All three swaylock invocations become `qs ipc call lock lock`:

```
timeout 600 'qs ipc call lock lock; niri msg action power-off-monitors' \
            resume 'niri msg action power-on-monitors'
before-sleep 'qs ipc call lock lock'
lock 'qs ipc call lock lock'
```

(Line-continuation backslash above is for the spec only — see
`swayidle/README.md` gotcha; the real file keeps each directive on one
physical line.)

The `lock 'qs ipc call lock lock'` line is what makes
`loginctl lock-session` from anywhere on the system still lock the screen:
logind broadcasts the `Lock` signal, swayidle's `lock` handler picks it up
and forwards to Quickshell.

### `niri/.config/niri/config.kdl`

Line 431 changes from:

```kdl
Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }
```

to:

```kdl
Super+Alt+L hotkey-overlay-title="Lock the Screen" { spawn "qs" "ipc" "call" "lock" "lock"; }
```

### `swaylock/`

Stow package deleted entirely (`~/dotfiles/swaylock/`). The `swaylock` binary
remains pacman-managed on the system but no dotfile invokes it.

### READMEs

- `swayidle/.config/swayidle/README.md` — update the timeline table and the
  always-on hooks to say `loginctl lock-session` and point at the Quickshell
  locker.
- `quickshell/.config/quickshell/` — add a doc-comment header in
  `LockScreen.qml` explaining: ext-session-lock-v1, PAM config = `login`,
  logind Lock/Unlock signal listener, and the
  "if quickshell crashes while locked you need a TTY" caveat.

## Idle-cost analysis

While unlocked, the cost of integration is:

- One dormant `WlSessionLock { locked: false }` (no surface mapped, no GPU
  resources).
- One dormant `PamContext { active: false }` (no PAM session open).
- One `DBusObject` subscription on `org.freedesktop.login1.Manager` — a
  single match rule, negligible.

No separate process, no extra DBus connection, no extra QML scene graph
load. The IpcHandler registers a single Quickshell-internal IPC target and
listens on Quickshell's existing socket; no system DBus involvement. Idle
delta from today is ~hundreds of KB of QML object graph. Locked
steady-state is identical to a separate-package design (one `qs` process
either way).

## Risks and failure modes

- **Quickshell crashes while locked.** ext-session-lock-v1 contract: the
  compositor keeps the screen blanked until a new lock client claims the
  lock or the compositor itself is restarted. Recovery is `Ctrl+Alt+F2` →
  TTY login → restart the session. Same failure mode as swaylock.
- **First-time test risk: getting locked out.** Mitigation: before wiring
  the real `swayidle` config, test with a short-timeout override
  (`swayidle -w timeout 30 'loginctl lock-session'` in a foreground
  terminal) and keep a TTY ready (`Ctrl+Alt+F2`). If the locker fails to
  appear or fails to accept the password, kill `swayidle`, fix, re-run.
- **PAM `login` config missing.** Stock on Arch (`/etc/pam.d/login` ships
  with the base install). If the user has a non-standard PAM setup we'll
  see `PamResult.Error` on first run; switch `pam.config` to a known-good
  service (e.g. `system-local-login`).
- **IPC socket missing.** `qs ipc call` requires the running Quickshell
  process to have started successfully. If `qs` crashed, the IPC call fails
  and nothing locks. Verifiable with `qs ipc show` listing the `lock`
  target. swayidle / niri-spawn output is silent on failure — first-time
  test should confirm `qs ipc call lock lock` works from a terminal.
- **`loginctl unlock-session` ordering.** Called *after* `lock.locked = false`
  so logind agrees we're unlocked. Idempotent: re-calling has no effect.

## Verification (post-implementation)

1. **Manual lock:** `loginctl lock-session` from a terminal → cream box
   appears on every screen, password unlocks.
2. **Niri keybind:** `Super+Alt+L` → same.
3. **Idle 10m:** `swayidle -w timeout 30 'loginctl lock-session'` (override)
   wait 30 s → lock appears, screen powers off shortly after; mouse wake
   keeps lock visible.
4. **before-sleep:** `systemctl suspend` → wake → lock screen, no flash of
   desktop.
5. **Failed auth:** wrong password → status shows error + counter, field
   clears, re-focus works.
6. **Wrong-password storm:** repeat wrong password 5×, then correct →
   counter resets to 0 on success.
7. **Multi-monitor:** plug external monitor while locked → second surface
   maps; unlock works from either.
8. **Idle delta:** `ps -o rss,cmd -C quickshell` before and after adding the
   lock component — sanity check the integration cost (~MB-scale OK; tens
   of MB warrants investigation).

## Open questions

None. All decisions resolved during brainstorming. Implementation plan
should pick up from this spec.
