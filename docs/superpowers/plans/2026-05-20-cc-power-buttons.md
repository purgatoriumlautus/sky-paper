# CC power buttons (6-action grid, arm-then-confirm) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 3-cell CC footer (Sleep · Logout · Reboot) and the standalone `power-menu.sh` kitty TUI with a unified 6-action grid (Lock · Logout · Sleep / Hibernate · Reboot · Shutdown) inside the control center. Every action requires press-twice within 5s to fire (pulsing blink while armed). Mod+Space behavior unchanged; new Mod+Shift+E IPC opens the CC focused on the power section's first cell.

**Architecture:** Extend the existing `PowerActions.qml` singleton's command table from 3 → 6 entries. Replace `CcFooterRow.qml` with `PowerGridRow.qml`, instantiated twice in `ControlCenter.qml` (row 9 session, row 10 system, 2px gap between). Add `armedRow`/`armedCol`/`armTimer` state on the CC; Enter dispatches through `armOrFire`. Add a `togglePower` IPC in `Bar.qml` that opens the CC pre-focused on (row 9, col 0). Replace the niri keybind. Delete `power-menu.sh`.

**Tech Stack:** QML6 (Quickshell), Quickshell.Io `Process` + `IpcHandler`, niri keybinds.

**Spec:** `docs/superpowers/specs/2026-05-20-cc-power-buttons-design.md`

**Branch policy:** Work on a feature branch off `laniakea`; verify end-to-end live; merge back only when green. Per project memory: never commit to `laniakea` directly.

---

## File Structure

**New files:**

- `quickshell/.config/quickshell/PowerGridRow.qml` — one power row (3 cells). Props: `cc`, `rowIndex` (CC row index, 9 or 10), `rowIdx` (0 = session, 1 = system), `labels` (3-string array). Reads `cc.focusedRow`/`cc.footerCol` for selection; reads `cc.armedRow`/`cc.armedCol` for the pulse animation. Mouse click → calls `cc.armOrFire(rowIndex, col)`. Sibling of (and modeled on) the deleted `CcFooterRow.qml`.

**Modified files:**

- `quickshell/.config/quickshell/PowerActions.qml` — extend `cmds` array from 3 → 6 entries. Update header comment.
- `quickshell/.config/quickshell/ControlCenter.qml` — bump `rowCount` 10 → 11; add `armedRow`/`armedCol` + `armTimer`; add `armCell`/`disarm`/`armOrFire` helpers; route rows 9 & 10 through `armOrFire` in `handleEnter` and call `disarm()` on any J/K/H/L row-changing path; clear arm state on close; replace the single `CcFooterRow {}` with two `PowerGridRow {}` instances; remove the now-unused `runPower(idx)`.
- `quickshell/.config/quickshell/Bar.qml` — add `togglePower(): void` to the `IpcHandler`.
- `niri/.config/niri/config.kdl` — change line 610's Mod+Shift+E command from `spawn-sh "~/.config/niri/power-menu.sh"` to `spawn "qs" "ipc" "call" "controlcenter" "togglePower"`.

**Deleted files:**

- `quickshell/.config/quickshell/CcFooterRow.qml` — replaced by `PowerGridRow.qml`.
- `niri/.config/niri/power-menu.sh` — fully deprecated; no other callers.

---

## Validation model (no test framework)

This is a dotfiles/QML project. There is no `pytest`/`jest` here. The verification step in each task is one or more of:

- **QML live reload:** Quickshell hot-reloads on file change — no kill/restart needed for QML edits. If the bar/popup stops reacting or QML parse errors appear *only after restarting* (not after live-reload edits), per project memory that's a stale-cache false alarm — kill `qs` and clear cache to confirm.
- **`qs ipc call ...`** — call the IPC directly to validate handler wiring without a niri keybind round-trip.
- **Manual UI check** with explicit "expected" descriptions (focus highlight, blink, command fires).
- **`systemctl` / `loginctl` dry-runs**: where possible (e.g. `loginctl --help` to confirm the binary path), but for actions like reboot/poweroff the only safe test is "I see the arm-then-confirm flow work; I trust the systemctl command in PowerActions.qml without firing it." Lock + Sleep + Logout are safe to test live.

---

## Task 1: Branch off laniakea

**Files:** none (git only)

- [ ] **Step 1: Confirm clean tree on laniakea**

Run: `git status`
Expected: `On branch laniakea` and `nothing to commit, working tree clean` (or only `docs/` untracked, which is gitignored).

- [ ] **Step 2: Create feature branch**

Run: `git switch -c cc-power-buttons`
Expected: `Switched to a new branch 'cc-power-buttons'`.

- [ ] **Step 3: Confirm**

Run: `git branch --show-current`
Expected: `cc-power-buttons`.

---

## Task 2: Extend `PowerActions.qml` to 6 commands

**Files:**
- Modify: `quickshell/.config/quickshell/PowerActions.qml`

- [ ] **Step 1: Replace the file contents**

The current file has a 3-entry `cmds` array and a comment "Index matches the footer model: 0 Sleep, 1 Logout, 2 Reboot." Replace the whole file with:

```qml
pragma Singleton

import Quickshell
import Quickshell.Io

// Footer power actions. Index matches the row-major grid in ControlCenter.qml:
//   row 9  (session): 0 Lock, 1 Logout, 2 Sleep
//   row 10 (system):  3 Hibernate, 4 Reboot, 5 Shutdown
// Mapping from (rowIndex, footerCol): idx = (rowIndex - 9) * 3 + footerCol.
Singleton {
    id: root
    function run(idx) {
        var cmds = [
            ["loginctl", "lock-session"],                                  // 0 Lock
            ["niri", "msg", "action", "quit", "--skip-confirmation"],      // 1 Logout
            ["systemctl", "suspend"],                                      // 2 Sleep
            ["systemctl", "hibernate"],                                    // 3 Hibernate
            ["systemctl", "reboot"],                                       // 4 Reboot
            ["systemctl", "poweroff"],                                     // 5 Shutdown
        ];
        proc.command = cmds[idx];
        proc.running = true;
    }
    Process { id: proc }
}
```

- [ ] **Step 2: Sanity-check the binaries exist**

Run: `command -v loginctl systemctl niri`
Expected: three absolute paths printed, one per line.

- [ ] **Step 3: Do NOT commit yet**

`PowerActions.qml` referenced from `ControlCenter.qml`'s `runPower` only — that caller is going away in Task 4. We commit Tasks 2–4 together so no commit references a broken intermediate state.

---

## Task 3: Create `PowerGridRow.qml`

**Files:**
- Create: `quickshell/.config/quickshell/PowerGridRow.qml`

- [ ] **Step 1: Write the file**

Create `quickshell/.config/quickshell/PowerGridRow.qml` with exactly:

```qml
import QtQuick
import Quickshell

// One row of three power-action cells. Modeled on the old CcFooterRow but
// with arm-then-confirm: a cell is "armed" when cc.armedRow/Col match —
// it pulses between Theme.accentText and Theme.bg until the 5 s armTimer
// expires, the user moves focus, or the user presses Enter a second time
// (which fires the action via cc.armOrFire).
//
// Flat command index (matches PowerActions.run): idx = rowIdx * 3 + col.
Item {
    id: row
    property var cc
    property int rowIndex: 9
    property int rowIdx: 0
    property var labels: ["A", "B", "C"]

    width: cc ? cc.width : 0
    height: 38

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === row.rowIndex) ? Theme.accentSoft : "transparent"
    }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: row.labels
            delegate: Rectangle {
                id: cell
                required property int index
                required property string modelData
                readonly property bool sel: cc && cc.focusedRow === row.rowIndex && cc.footerCol === index
                readonly property bool armed: cc && cc.armedRow === row.rowIndex && cc.armedCol === index
                width: (row.width - 24 - 8) / 3
                height: 28
                // base fill: armed phase set by SequentialAnimation when armed;
                // otherwise selected = accentText, idle = bg.
                color: armed ? armBg : (sel ? Theme.accentText : Theme.bg)
                border.color: Theme.borderDim

                // pulse state: when armed, animation alternates armPhase 0↔1
                // every 500 ms. armBg and labelColor read off armPhase so the
                // cell fill and its label flip together.
                property int armPhase: 0
                readonly property color armBg: armPhase === 0 ? Theme.accentText : Theme.bg
                readonly property color labelColor:
                    armed ? (armPhase === 0 ? Theme.barBg : Theme.fg)
                          : (sel ? Theme.barBg : Theme.fg)

                SequentialAnimation {
                    running: cell.armed
                    loops: Animation.Infinite
                    PropertyAction { target: cell; property: "armPhase"; value: 0 }
                    PauseAnimation { duration: 500 }
                    PropertyAction { target: cell; property: "armPhase"; value: 1 }
                    PauseAnimation { duration: 500 }
                }

                CcText {
                    anchors.centerIn: parent
                    text: modelData
                    color: cell.labelColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        row.cc.focusedRow = row.rowIndex;
                        row.cc.footerCol = cell.index;
                        row.cc.armOrFire(row.rowIndex, cell.index);
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Do NOT live-reload yet**

This file references `cc.armedRow`/`cc.armedCol`/`cc.armOrFire`, all of which arrive in Task 4. Loading it now would parse-error.

---

## Task 4: Rewire `ControlCenter.qml`

**Files:**
- Modify: `quickshell/.config/quickshell/ControlCenter.qml`

This task has multiple small edits to the same file. Apply them in the order listed.

- [ ] **Step 1: Update the top-of-file row grammar comment**

Find the comment block at the top describing rows. Replace lines 12–17 (the row map) with:

```qml
// Rows (top → bottom):
//   0 Brightness (slider)   5 BT (device picker)
//   1 Volume (slider)       6 Wifi (picker + password)
//   2 Airplane (toggle)     7 Output (sink picker)
//   3 Warm (toggle)         8 Power profile (EPP cycler)
//   4 Auto-suspend (toggle) 9 Power session:  Lock · Logout · Sleep
//                          10 Power system:   Hibernate · Reboot · Shutdown
// Power rows 9/10 use arm-then-confirm: first Enter on a cell arms it
// (cell pulses, 5 s timer); second Enter on the SAME cell fires the
// PowerActions command and closes the CC. Moving focus disarms.
```

- [ ] **Step 2: Bump `rowCount` and add armed-state properties**

In the existing properties block (currently `readonly property int rowCount: 10` + `property int focusedRow: 0` + `property int footerCol: 0`), change `rowCount: 10` to `rowCount: 11` and add two lines:

```qml
readonly property int rowCount: 11
property int focusedRow: 0
property int footerCol: 0          // 0..2 within power footer rows (idx 9, 10)

// arm-then-confirm: when armedRow/Col point at a cell on rows 9 or 10,
// that cell pulses for up to 5 s. Second Enter on the same cell fires;
// moving focus, pressing Esc, or letting the timer expire disarms.
property int armedRow: -1
property int armedCol: -1
```

- [ ] **Step 3: Add the `armTimer` and helper functions**

Just after the `Connections { target: AudioCtl ... }` block, add:

```qml
Timer {
    id: armTimer
    interval: 5000
    onTriggered: { cc.armedRow = -1; cc.armedCol = -1; }
}

function armCell(rowIndex, col) {
    cc.armedRow = rowIndex;
    cc.armedCol = col;
    armTimer.restart();
}
function disarm() {
    if (cc.armedRow === -1 && cc.armedCol === -1) return;
    cc.armedRow = -1;
    cc.armedCol = -1;
    armTimer.stop();
}
function armOrFire(rowIndex, col) {
    if (cc.armedRow === rowIndex && cc.armedCol === col) {
        PowerActions.run((rowIndex - 9) * 3 + col);
        cc.disarm();
        cc.closeCc();
    } else {
        cc.armCell(rowIndex, col);
    }
}
```

- [ ] **Step 4: Clear arm state on close**

The existing `closeAnim`'s `onFinished` reads:

```qml
onFinished: { cc.visible = false; cc.closing = false; }
```

Replace it with:

```qml
onFinished: { cc.visible = false; cc.closing = false; cc.disarm(); }
```

Also extend the open-path reset in `onVisibleChanged` (the block starting `onVisibleChanged: if (visible) {`) — after the existing `cc.footerCol = 0;` line, add:

```qml
cc.armedRow = -1;
cc.armedCol = -1;
```

(Belt + braces: if the close animation was cut short by a re-open, the armTimer's `onTriggered` would still fire later. The explicit clear on each open guarantees a fresh state.)

- [ ] **Step 5: Replace `runPower` with arm/fire dispatch in `handleEnter`**

Find `handleEnter()`. The `case 9: cc.runPower(cc.footerCol); break;` line becomes two cases:

```qml
case 9:
case 10: cc.armOrFire(cc.focusedRow, cc.footerCol); break;
```

(Do not also add a `case 8` here — Power profile cycling is unchanged.)

- [ ] **Step 6: Add row-10 case to `dispatchHL`**

Find `dispatchHL(dir)`. The existing `case 9: cc.footerCol = Math.max(0, Math.min(2, cc.footerCol + dir)); break;` becomes two cases that also disarm:

```qml
case 9:
case 10: {
    cc.disarm();
    cc.footerCol = Math.max(0, Math.min(2, cc.footerCol + dir));
    break;
}
```

- [ ] **Step 7: Disarm on row-changing J/K and on Esc**

In the `Keys.onPressed` handler in the `panel` Rectangle, find the J/K and Esc branches. Three small changes:

The current J/Down branch:

```qml
} else if (k === Qt.Key_J || k === Qt.Key_Down) {
    if (listOpen) cc.scrollList(+1);
    else cc.focusedRow = (cc.focusedRow + 1) % cc.rowCount;
    event.accepted = true;
```

Becomes:

```qml
} else if (k === Qt.Key_J || k === Qt.Key_Down) {
    if (listOpen) cc.scrollList(+1);
    else { cc.disarm(); cc.focusedRow = (cc.focusedRow + 1) % cc.rowCount; }
    event.accepted = true;
```

The K/Up branch — same shape:

```qml
} else if (k === Qt.Key_K || k === Qt.Key_Up) {
    if (listOpen) cc.scrollList(-1);
    else { cc.disarm(); cc.focusedRow = (cc.focusedRow - 1 + cc.rowCount) % cc.rowCount; }
    event.accepted = true;
```

The Esc/Q branch:

```qml
if (k === Qt.Key_Escape || k === Qt.Key_Q) {
    if (listOpen) cc.closeList(); else cc.closeCc();
    event.accepted = true;
```

Becomes:

```qml
if (k === Qt.Key_Escape || k === Qt.Key_Q) {
    if (cc.armedRow !== -1) cc.disarm();
    else if (listOpen) cc.closeList();
    else cc.closeCc();
    event.accepted = true;
```

H/L already disarm via the `dispatchHL` change in Step 6 — no further edit there.

- [ ] **Step 8: Remove `runPower`**

Find the comment block + function:

```qml
// --- footer power actions ---
function runPower(idx) {
    PowerActions.run(idx);
    cc.closeCc();
}
```

Delete it. All callers are gone (handleEnter now goes through `armOrFire`; `CcFooterRow.qml` will be deleted in Task 5).

- [ ] **Step 9: Replace the `CcFooterRow {}` instantiation with two `PowerGridRow {}`s**

In the `Column { id: shell ... }` block, find:

```qml
// 9 — Footer: Sleep · Logout · Reboot
CcFooterRow { cc: cc; rowIndex: 9 }
```

Replace it with:

```qml
// 9 — Power session: Lock · Logout · Sleep
PowerGridRow {
    cc: cc; rowIndex: 9; rowIdx: 0
    labels: ["Lock", "Logout", "Sleep"]
}
// 2 px safety-grade gap — only break in the otherwise-flush CC stack
Item { width: cc.width; height: 2 }
// 10 — Power system: Hibernate · Reboot · Shutdown
PowerGridRow {
    cc: cc; rowIndex: 10; rowIdx: 1
    labels: ["Hibernate", "Reboot", "Shutdown"]
}
```

- [ ] **Step 10: Live-reload + visual check (no commit yet)**

QML edits hot-reload — open the CC with `qs ipc call controlcenter open`. Verify:

1. The footer is now two 3-cell rows with a tiny gap between them.
2. Mod+Space / `qs ipc call controlcenter toggle` opens the CC on row 0 (Brightness highlighted) as before.
3. Press J ten times to walk down to row 10 — selection highlight crosses both power rows cleanly.
4. On row 9 col 0 (Lock), press Enter — the Lock cell starts pulsing (~0.5 s cycle) between blue and cream.
5. Press J — selection drops to row 10, Lock unpulses (disarm on focus move).
6. Press Enter on row 10 col 0 (Hibernate) — it pulses. Wait ~5 s — pulse stops (timer disarm).
7. Press Enter twice quickly on Lock — screen locks (swaylock comes up via logind signal). Unlock to continue.
8. Re-open CC, press Enter twice on Logout — niri quits. (Skip this if you don't want to relog right now.)
9. Press Enter twice on Sleep — system suspends. Wake to continue.

If QML parse errors appear *only after a manual `qs` restart* (not during live-reload), per project memory that's a stale-cache false alarm — `pkill qs && rm -rf ~/.cache/quickshell 2>/dev/null; qs &` to confirm.

If any check fails, fix before committing.

- [ ] **Step 11: Delete `CcFooterRow.qml`**

Run: `git rm quickshell/.config/quickshell/CcFooterRow.qml`
Expected: `rm 'quickshell/.config/quickshell/CcFooterRow.qml'`

- [ ] **Step 12: Commit Tasks 2–4 together**

```bash
git add quickshell/.config/quickshell/PowerActions.qml \
        quickshell/.config/quickshell/PowerGridRow.qml \
        quickshell/.config/quickshell/ControlCenter.qml
git commit -m "$(cat <<'EOF'
quickshell: CC power grid (6 actions, arm-then-confirm)

Replaces the 3-cell footer (Sleep · Logout · Reboot) with two 3-cell
rows — session (Lock · Logout · Sleep) and system (Hibernate · Reboot
· Shutdown), separated by a 2px gap. Every cell needs press-twice
within 5s to fire; the armed cell pulses Theme.accentText↔Theme.bg.
Moving focus, Esc, or the 5s timeout disarms.

PowerActions.run gains Lock (loginctl lock-session), Hibernate
(systemctl hibernate), Shutdown (systemctl poweroff). Indices map
row-major across the two rows.
EOF
)"
```

---

## Task 5: Add `togglePower` IPC in `Bar.qml`

**Files:**
- Modify: `quickshell/.config/quickshell/Bar.qml`

- [ ] **Step 1: Extend the IpcHandler**

Find the `IpcHandler { target: "controlcenter" ... }` block (currently three functions: `toggle`, `open`, `close`). Add a fourth function. The block becomes:

```qml
// niri bind → `qs ipc call controlcenter toggle` (Mod+Space)
//          → `qs ipc call controlcenter togglePower` (Mod+Shift+E)
IpcHandler {
    target: "controlcenter"
    function toggle(): void { cc.toggleCc(); }
    function open(): void { cc.openCc(); }
    function close(): void { cc.closeCc(); }
    function togglePower(): void {
        if (cc.visible && !cc.closing) { cc.closeCc(); return; }
        cc.focusedRow = 9;
        cc.footerCol = 0;
        cc.openCc();
    }
}
```

- [ ] **Step 2: Validate the IPC wires up**

Run: `qs ipc call controlcenter togglePower`
Expected: CC opens with row 9 col 0 (Lock) highlighted.

Run it again: `qs ipc call controlcenter togglePower`
Expected: CC closes.

Run a third time: `qs ipc call controlcenter togglePower`
Expected: CC re-opens, focused on Lock again (state reset on each open path).

- [ ] **Step 3: Commit**

```bash
git add quickshell/.config/quickshell/Bar.qml
git commit -m "quickshell: Bar togglePower IPC (opens CC on Lock cell)"
```

---

## Task 6: Switch the niri Mod+Shift+E keybind

**Files:**
- Modify: `niri/.config/niri/config.kdl`

- [ ] **Step 1: Edit line 610**

The current line 610 is:

```kdl
    Mod+Shift+E hotkey-overlay-title="Power menu" { spawn-sh "~/.config/niri/power-menu.sh"; }
```

Replace it with:

```kdl
    Mod+Shift+E hotkey-overlay-title="Power menu" { spawn "qs" "ipc" "call" "controlcenter" "togglePower"; }
```

Also update the comment above it (currently `// Power menu (lock/logout/suspend/reboot/shutdown) via tofi. Same bind toggles.`) to:

```kdl
    // Power menu (lock/logout/sleep/hibernate/reboot/shutdown) inside the
    // control center. Opens pre-focused on Lock; re-pressing the bind
    // toggles the CC closed.
```

- [ ] **Step 2: Reload niri config**

niri auto-reloads `config.kdl` on save. Confirm with: `niri msg event-stream | head -1` (just ensures niri is alive) — actual test is the next step.

- [ ] **Step 3: Test the keybind**

Press Mod+Shift+E.
Expected: CC opens with Lock highlighted.

Press Mod+Shift+E again.
Expected: CC closes.

- [ ] **Step 4: Commit**

```bash
git add niri/.config/niri/config.kdl
git commit -m "niri: Mod+Shift+E opens CC power grid (was tofi power menu)"
```

---

## Task 7: Delete `power-menu.sh`

**Files:**
- Delete: `niri/.config/niri/power-menu.sh`

- [ ] **Step 1: Verify no other references**

Run: `grep -rn "power-menu\.sh" . 2>/dev/null | grep -v '^\.git/' | grep -v '^\./docs/'`
Expected: no output (or only matches inside `docs/` specs, which are documentation of the old state).

- [ ] **Step 2: Delete the file**

Run: `git rm niri/.config/niri/power-menu.sh`
Expected: `rm 'niri/.config/niri/power-menu.sh'`

- [ ] **Step 3: Commit**

```bash
git commit -m "niri: drop power-menu.sh (replaced by CC power grid)"
```

---

## Task 8: End-to-end verification

**Files:** none (manual)

- [ ] **Step 1: Cold-restart Quickshell once**

Per project memory, hot-reload is the source of truth, but a final cold path catches anything that only manifests on first load.

Run: `pkill qs; sleep 1; qs &`
Wait ~2 s. Bar should reappear with all rows.

- [ ] **Step 2: Verify Mod+Space path**

Press Mod+Space.
Expected: CC opens on row 0 (Brightness highlighted). Press Mod+Space again — CC closes.

- [ ] **Step 3: Verify Mod+Shift+E path**

Press Mod+Shift+E.
Expected: CC opens on row 9 col 0 (Lock highlighted).

- [ ] **Step 4: Walk the grid with H/L and J/K**

From the Lock-focused state:
- L → Logout highlighted.
- L → Sleep highlighted.
- L → stays on Sleep (clamped at col 2).
- J → Shutdown highlighted (row 10 col 2). H → Reboot. H → Hibernate. H → stays.
- K → back to row 9 (Lock).

- [ ] **Step 5: Arm-then-confirm on a safe action**

Walk to Lock. Press Enter — cell pulses. Press J — pulse stops (disarm). Press K to return to Lock. Press Enter — pulses. Wait 5 s — pulse stops (timer disarm). Press Enter — pulses. Press Enter again — screen locks.

- [ ] **Step 6: Arm-then-confirm with Esc disarm**

Re-open CC via Mod+Shift+E. Press Enter on Lock — cell pulses. Press Esc — pulse stops, CC stays open (Esc disarms before closing). Press Esc again — CC closes.

- [ ] **Step 7: Sleep via the grid**

Mod+Shift+E → L → L (Sleep highlighted) → Enter → wait for pulse → Enter again. System suspends. Wake to continue.

- [ ] **Step 8: Confirm `power-menu.sh` is gone**

Press Mod+Shift+E — should now do the CC behavior above, *not* spawn a kitty TUI.

Run: `test -e ~/.config/niri/power-menu.sh && echo PRESENT || echo GONE`
Expected: `GONE`.

- [ ] **Step 9: Confirm rows 0-8 are unaffected**

Mod+Space → walk through Brightness, Volume, Airplane, Warm, Auto-suspend, BT, Wifi, Output, Power profile. All should behave exactly as before — no regressions from the rowCount bump.

---

## Task 9: Merge to `laniakea`

**Files:** none (git only)

- [ ] **Step 1: Confirm branch is clean**

Run: `git status`
Expected: `On branch cc-power-buttons` and `nothing to commit, working tree clean`.

- [ ] **Step 2: View the commit list**

Run: `git log --oneline laniakea..HEAD`
Expected: four commits in order:
1. `quickshell: CC power grid (6 actions, arm-then-confirm)`
2. `quickshell: Bar togglePower IPC (opens CC on Lock cell)`
3. `niri: Mod+Shift+E opens CC power grid (was tofi power menu)`
4. `niri: drop power-menu.sh (replaced by CC power grid)`

- [ ] **Step 3: Fast-forward `laniakea`**

```bash
git switch laniakea
git merge --ff-only cc-power-buttons
```

Expected: `Fast-forward` plus a list of the four commits.

- [ ] **Step 4: Optional cleanup**

Run: `git branch -d cc-power-buttons`
Expected: `Deleted branch cc-power-buttons`.
