# Control Center power buttons — 6-action grid with arm-then-confirm

**Date:** 2026-05-20
**Scope:** Quickshell control center + niri keybind + delete `power-menu.sh`

## Goal

Replace the current single-row CC footer (Sleep · Logout · Reboot) and the standalone kitty TUI (`power-menu.sh`) with a unified 6-button power section inside the control center, accessible from Mod+Space (lands on row 0 as today) or directly via Mod+Shift+E (lands on the power section's first cell).

All six actions require **press-twice within 5s to fire** — no asymmetric "danger row only" rule, no implicit destructive bias. Lock is included; pressing Lock once arms it, second press locks the session.

## Layout

The CC popup currently has 10 rows (0..9), with row 9 being a single 3-cell footer (`CcFooterRow.qml`). After this change it has **11 rows**: rows 9 and 10 are each a 3-cell power row.

```
Row 9  — session (reversible actions)
┌──────────┬──────────┬──────────┐
│   Lock   │  Logout  │  Sleep   │
└──────────┴──────────┴──────────┘
Row 10 — system (state-affecting actions)
┌──────────┬──────────┬──────────┐
│Hibernate │  Reboot  │ Shutdown │
└──────────┴──────────┴──────────┘
```

- Each row: 38px tall, three equal cells, same border treatment as the existing footer.
- Row 10 is offset from row 9 by a **2px transparent gap** — a visual safety grade without being loud. (Other CC rows have no gap between them; this single gap is the only signal.)
- Labels: text only. "Hibernate" and "Shutdown" must fit inside ~88px cells at the existing CC font size (Terminess Nerd, fontSize 13). Verify in implementation; abbreviate only if necessary.

## Actions and commands

Indices 0..5 map row-major across the grid:

| idx | Label     | Row | Col | Command                                       |
|----:|-----------|----:|----:|-----------------------------------------------|
|   0 | Lock      |   9 |   0 | `loginctl lock-session`                       |
|   1 | Logout    |   9 |   1 | `niri msg action quit --skip-confirmation`    |
|   2 | Sleep     |   9 |   2 | `systemctl suspend`                           |
|   3 | Hibernate |  10 |   0 | `systemctl hibernate`                         |
|   4 | Reboot    |  10 |   1 | `systemctl reboot`                            |
|   5 | Shutdown  |  10 |   2 | `systemctl poweroff`                          |

Lock uses `loginctl lock-session` (logind fires its Lock signal, swayidle/swaylock react) rather than calling swaylock directly — keeps the impl decoupled from the swaylock binary path.

Hibernate is available on this machine (confirmed by user); no pre-check needed. If it ever isn't, `systemctl hibernate` fails non-fatally with a logged error.

## Arm-then-confirm behavior

All six buttons share the same flow:

- **First Enter** on a cell → arms that cell. Cell enters a blinking state (see "Blink visual" below). A 5-second timer starts.
- **Second Enter** on the **same** armed cell, within 5s → runs the command and closes the CC.
- **Second Enter** on a **different** cell while armed → disarms the previous, arms the new one. (No "double-arm" state — at most one cell is armed at any time.)
- **5s timer fires** → disarm, cell returns to its idle/focused appearance.
- **Focus-changing key** (J/K/H/L when not in list-mode) → disarm.
- **Esc/Q** → if armed, disarm only (does not also close). If not armed, current behavior (close list, else close CC).
- **CC closes for any reason** while armed → disarm and clear the timer (so reopening doesn't show a ghost-armed cell).

### Blink visual

During the armed window, the cell's fill color cycles between `Theme.accentText` (the selected/highlighted color used by the existing footer) and `Theme.bg` (the idle color) on a ~0.5s SequentialAnimation. No red — Lock would look misleading. The label color cycles inversely (`Theme.barBg` ↔ `Theme.fg`) so the text stays readable on both phases. The animation stops and the cell reverts to its current focus/idle state the moment the cell disarms (timer fire, focus move, second Enter, CC close).

## Keyboard nav

`ControlCenter.qml`'s `rowCount` goes from 10 to 11. Existing J/K/H/L logic is unchanged:

- J/K crosses between rows 9 and 10 naturally.
- H/L moves `footerCol` (0..2) within whichever power row is focused.
- Enter dispatches to the arm/fire logic above instead of calling `runPower` directly.

`footerCol` semantics stay the same — it's the active column index within the currently focused power row.

## Components

### `PowerActions.qml` (singleton, modified)

Extend the existing `run(idx)` array from 3 entries to 6:

```qml
var cmds = [
    ["loginctl", "lock-session"],                                    // 0 Lock
    ["niri", "msg", "action", "quit", "--skip-confirmation"],        // 1 Logout
    ["systemctl", "suspend"],                                        // 2 Sleep
    ["systemctl", "hibernate"],                                      // 3 Hibernate
    ["systemctl", "reboot"],                                         // 4 Reboot
    ["systemctl", "poweroff"],                                       // 5 Shutdown
];
```

Indices match the row-major grid mapping above. No other changes.

### `PowerGridRow.qml` (new, replaces `CcFooterRow.qml`)

A single power row component. Props:

- `cc` — control-center reference (existing pattern)
- `rowIndex` — the CC row index (9 or 10)
- `rowIdx` — 0 for session row, 1 for system row (used to compute the flat command index: `rowIdx * 3 + col`)

Renders three equal cells with labels from a `model` array passed in (or hard-coded per row). Each cell:

- Shows label centered.
- Tints when `cc.focusedRow === rowIndex && cc.footerCol === col` (matches existing footer styling).
- Runs a pulsing `SequentialAnimation` when `cc.armedRow === rowIndex && cc.armedCol === col`.
- `MouseArea` → first click arms, second click fires (same flow as keyboard Enter).

`CcFooterRow.qml` is deleted.

### `ControlCenter.qml` (modified)

- `readonly property int rowCount: 11` (was 10).
- New state:
  ```qml
  property int armedRow: -1
  property int armedCol: -1
  Timer {
      id: armTimer
      interval: 5000
      onTriggered: { cc.armedRow = -1; cc.armedCol = -1; }
  }
  ```
- New helpers:
  ```qml
  function armCell(row, col) {
      cc.armedRow = row;
      cc.armedCol = col;
      armTimer.restart();
  }
  function disarm() {
      cc.armedRow = -1;
      cc.armedCol = -1;
      armTimer.stop();
  }
  ```
- `handleEnter()` — for rows 9 and 10, dispatch through `armOrFire(row, col)`:
  ```qml
  case 9:
  case 10: {
      var col = cc.footerCol;
      if (cc.armedRow === cc.focusedRow && cc.armedCol === col) {
          PowerActions.run((cc.focusedRow - 9) * 3 + col);
          cc.closeCc();
      } else {
          cc.armCell(cc.focusedRow, col);
      }
      break;
  }
  ```
- `dispatchHL(dir)` — for rows 9 and 10, move `footerCol` as today and **disarm** as a side effect (any focus move disarms).
- J/K row navigation also disarms (call `disarm()` whenever `focusedRow` changes via J/K).
- Esc handling: if `armedRow !== -1`, just disarm (do not also close list / close CC). Otherwise existing behavior.
- `onVisibleChanged` (close path) — clear arm state and timer.
- Replace the single `CcFooterRow { cc: cc; rowIndex: 9 }` with two instances:
  ```qml
  PowerGridRow { cc: cc; rowIndex: 9; rowIdx: 0; labels: ["Lock", "Logout", "Sleep"] }
  PowerGridRow { cc: cc; rowIndex: 10; rowIdx: 1; labels: ["Hibernate", "Reboot", "Shutdown"] }
  ```
- Remove the old `runPower(idx)` — the only callers were the row-9 Enter handler (now arm/fire) and `CcFooterRow.qml`'s `MouseArea` (now in `PowerGridRow.qml`). Nothing else references it.

### `Bar.qml` (modified)

Add a new IPC method:

```qml
function togglePower(): void {
    if (cc.visible && !cc.closing) { cc.closeCc(); return; }
    cc.focusedRow = 9;
    cc.footerCol = 0;
    cc.openCc();
}
```

The existing `toggle/open/close` methods remain unchanged — Mod+Space still lands on row 0 (Brightness) as today. Only `togglePower` enters via the power section.

### `niri/config.kdl` (modified)

Line 610:

- **Before:** `Mod+Shift+E hotkey-overlay-title="Power menu" { spawn-sh "~/.config/niri/power-menu.sh"; }`
- **After:** `Mod+Shift+E hotkey-overlay-title="Power menu" { spawn "qs" "ipc" "call" "controlcenter" "togglePower"; }`

### `niri/.config/niri/power-menu.sh` (deleted)

File removed entirely. No callers remain after the keybind update.

## Edge cases

- **Hibernate availability:** confirmed available on this machine; no pre-check.
- **CC closes mid-arm:** `onVisibleChanged` (close path) calls `disarm()` — no ghost fires on reopen.
- **Mod+Shift+E while CC already open elsewhere:** behaves as toggle — closes the CC. (Re-pressing reopens it on the power row.) This matches the existing Mod+Space toggle semantics. If we want "re-press refocuses to power row without closing," that's a different decision — current spec says toggle.
- **Mouse click on an unarmed cell, then mouse click on a different cell:** disarms first, arms second (same as keyboard Enter on a different cell).
- **Repeated mouse clicks on the same armed cell:** second click fires.
- **Polkit prompt:** none of these commands require polkit for a logged-in user on a normal systemd-logind setup (`loginctl lock-session`, `systemctl suspend|hibernate|reboot|poweroff` are all permitted via logind's `inhibit`/auth-as-user policy). No new polkit rule needed.

## Out of scope

- Power profile (EPP) row at row 8 — unchanged.
- Lock-screen UI (swaylock styling, fingerprint, etc.) — unchanged.
- Suspend inhibition row at row 4 — unchanged.
- Changing the look/animation of non-power CC rows.
- Adding any new power action beyond the six listed (e.g. "soft reboot to firmware", "kexec").

## Files touched

| Path                                                  | Change  |
|-------------------------------------------------------|---------|
| `quickshell/.config/quickshell/PowerActions.qml`      | edit (3→6 commands) |
| `quickshell/.config/quickshell/CcFooterRow.qml`       | delete  |
| `quickshell/.config/quickshell/PowerGridRow.qml`      | new     |
| `quickshell/.config/quickshell/ControlCenter.qml`     | edit (rowCount, arm state, two PowerGridRow instances, Esc/disarm rules) |
| `quickshell/.config/quickshell/Bar.qml`               | edit (add `togglePower` IPC) |
| `niri/.config/niri/config.kdl`                        | edit (line 610 keybind) |
| `niri/.config/niri/power-menu.sh`                     | delete  |
