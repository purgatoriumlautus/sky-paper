# Notifications (mako + Sky Paper + CC "Quiet" row) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire mako as the Wayland notification daemon, themed pixel-aligned with the existing bar/CC/lock visuals, and add a "Quiet" row in the ControlCenter that toggles DND via `makoctl mode -t do-not-disturb`.

**Architecture:** New stow package `mako/` ships an ini config that maps Sky Paper tokens onto mako and pins popups to the top-left at the same outer-border coordinates a niri window would occupy. niri `spawn-at-startup "mako"` runs the daemon. A new `Notifications` Quickshell singleton wraps `makoctl mode` (refresh on CC open + optimistic toggle, same pattern as `Radio`/`SuspendInhibit`). A new `CcToggleRow` "Quiet" is inserted at CC index 5, shifting downstream indices BT 5→6, Wifi 6→7, Output 7→8, Power profile 8→9, power footer 9/10→10/11. Every modulus, switch case, and `openRow` check in `ControlCenter.qml` shifts by 1.

**Tech Stack:** mako 1.x (ini config + Pango markup + makoctl), QML6 (Quickshell singleton + Process), niri spawn-at-startup, stow.

**Spec:** `docs/superpowers/specs/2026-05-20-notifications-design.md`

**Branch policy:** Work on a feature branch off `laniakea`; verify end-to-end live; merge back only when green. Per project memory: never commit to `laniakea` directly.

---

## File Structure

**New files:**

- `mako/.config/mako/config` — ini config, ~30 lines. Theme tokens, top-left anchor, asymmetric margin `8,9,8,9` (top-right-bottom-left) for pixel-exact alignment with a niri window's outer-border corner, urgency styling for low/high.
- `quickshell/.config/quickshell/Notifications.qml` — singleton wrapping `makoctl mode`. Props: `dnd:bool`. Functions: `refresh()`, `toggle()`. Same shape as `Radio.qml` / `SuspendInhibit.qml`.

**Modified files:**

- `quickshell/.config/quickshell/ControlCenter.qml` — insert "Quiet" `CcToggleRow` at index 5 between Auto-suspend and BT; shift downstream row indices, switch cases, modulus, `openRow` checks, `armOrFire` flat-index math, header row-map comment. Add `Notifications.refresh()` to `refresh()`.
- `niri/.config/niri/config.kdl` — add `spawn-at-startup "mako"` adjacent to existing spawn lines.
- `CONTEXT.md` — drop "swaync not configured" note; add mako entry to the Stack table; add `Notifications` to the singletons list; bump the ControlCenter row map (Quiet at row 5, downstream rows renumbered).
- `todos.txt` — mark #2 done.

**Deleted files:** none.

---

## Validation model (no test framework)

This is a dotfiles/QML project. There is no `pytest`/`jest`. The verification step in each task is one or more of:

- **`pgrep -x mako`** — confirms the daemon is up.
- **`notify-send`** — fires a real notification to verify rendering, styling, position.
- **`makoctl mode`** / **`makoctl mode -t do-not-disturb`** — confirms DND toggle round-trips through mako.
- **QML live reload:** Quickshell hot-reloads on file change — no kill/restart needed. Per [[reference-quickshell-stale-cache-errors]], if QML errors appear ONLY after a manual `qs` restart and not during live-reload edits, that's a stale-cache false alarm; live-reload is the source of truth for "the QML parses". Use `qs kill && rm -rf ~/.cache/quickshell && qs &` to validate from scratch only when you suspect that.
- **Manual UI check** with explicit "expected" descriptions: focus highlight, switch flip, popup at expected pixel coords.

---

## Task 1: Branch off laniakea

**Files:** none (git only)

- [ ] **Step 1: Confirm clean tree on laniakea**

Run: `git status`
Expected: `On branch laniakea`; tracked changes may exist (settings.local.json, init.lua, todos.txt, untracked `docs/` and `crossgrub/`) — these are pre-existing and unrelated.

- [ ] **Step 2: Create feature branch**

Run: `git switch -c mako-notifications`
Expected: `Switched to a new branch 'mako-notifications'`.

- [ ] **Step 3: Confirm**

Run: `git branch --show-current`
Expected: `mako-notifications`.

---

## Task 2: Install mako

**Files:** none (system package).

- [ ] **Step 1: Install via pacman**

Run: `sudo pacman -S --needed mako`
Expected: either `mako is up to date` or successful install. Exit code 0.

- [ ] **Step 2: Confirm binary + version**

Run: `mako --version && which makoctl`
Expected: a version string like `mako v1.x.y` and `/usr/bin/makoctl`.

- [ ] **Step 3: Confirm padding syntax** — mako padding values use space separation across all current versions. The spec mentions a comma-separated fallback as a defensive note; the plan uses the space form `padding=6 12` to be safe.

Run: `mako --help 2>&1 | head -1`
Expected: prints the help banner without crashing.

---

## Task 3: Create mako stow package

**Files:**
- Create: `mako/.config/mako/config`

- [ ] **Step 1: Create the directory tree**

Run: `mkdir -p ~/dotfiles/mako/.config/mako`
Expected: directory exists; `ls -ld ~/dotfiles/mako/.config/mako` shows it.

- [ ] **Step 2: Write the config**

Create `~/dotfiles/mako/.config/mako/config` with:

```ini
# mako — Sky Paper themed notifications.
# Popups land top-left, pixel-aligned to a niri window's outer-border corner:
# margin = 8 right 9 bottom 8 left 9, where 9 = niri gaps 8 + border 1, and
# 8 = the clear gap niri leaves between the bar's exclusive zone and a
# window's outer-border-top. See docs/superpowers/specs/2026-05-20-notifications-design.md.

font=Terminess Nerd Font Mono 16
background-color=#BFE4DED0
text-color=#1F1812
border-color=#C5BFB5
border-size=1
border-radius=0
padding=6 12
margin=8 9 8 9
width=300
height=32
anchor=top-left
default-timeout=5000
ignore-timeout=0
group-by=app-name
max-visible=4
max-history=50
layer=overlay
icons=0
max-icon-size=0
markup=1
format=<b>%s</b>  <span foreground="#7A716A">%b</span>

[urgency=low]
border-color=#7A716A
default-timeout=3000

[urgency=high]
border-color=#9C5450
default-timeout=0
```

- [ ] **Step 3: Stow it**

Run: `cd ~/dotfiles && stow mako`
Expected: no output (success) and `readlink ~/.config/mako` resolves into `~/dotfiles/mako/.config/mako`.

- [ ] **Step 4: Confirm the symlink**

Run: `ls -l ~/.config/mako/config`
Expected: symlink pointing into `~/dotfiles/mako/.config/mako/config`.

- [ ] **Step 5: Commit**

```bash
git add mako/
git commit -m "mako: add Sky Paper themed stow package"
```

---

## Task 4: Start mako once and smoke-test rendering

**Files:** none (runtime verification).

- [ ] **Step 1: Start mako manually for the smoke test**

Run: `pgrep -x mako >/dev/null || mako &; disown` (fish: `not pgrep -x mako; and mako &; and disown` — adjust to current shell). The intent is "start mako only if not already running."
Expected: `pgrep -x mako` returns a PID.

- [ ] **Step 2: Fire a basic notification**

Run: `notify-send "hello" "from mako"`
Expected: a popup appears at the top-left of the active output. Bold "hello" + muted "from mako" body. Square corners, 1px hairline border in `#C5BFB5`, cream-tinted bg.

- [ ] **Step 3: Pixel-check alignment against a niri window**

Open any niri window (e.g. `kitty &`). Visually compare: the popup's left edge sits at the same x as the kitty window's left outer-border edge; the popup's top edge sits at the same y as the kitty window's top outer-border edge.
Expected: alignment matches within 1px. If off, re-check `margin=8 9 8 9` ordering — mako's order is top-right-bottom-left.

- [ ] **Step 4: Urgency check**

Run: `notify-send -u critical "urgent" "sticks"` then `notify-send -u low "quiet" "fades fast"`
Expected: critical popup has `#9C5450` border and does NOT auto-dismiss; low popup has `#7A716A` border and dismisses in ~3s.

- [ ] **Step 5: Dismiss any sticky popups**

Run: `makoctl dismiss --all`
Expected: all popups gone.

- [ ] **Step 6: Stop the manual mako**

Run: `pkill -x mako`
Expected: `pgrep -x mako` returns nothing.

---

## Task 5: Add mako to niri spawn-at-startup

**Files:**
- Modify: `niri/.config/niri/config.kdl`

- [ ] **Step 1: Find the spawn block**

Run: `grep -n 'spawn-at-startup' ~/dotfiles/niri/.config/niri/config.kdl`
Expected: lines around 298–301 listing `qs`, `swaybg`, `swayidle`.

- [ ] **Step 2: Add the mako line**

Insert `spawn-at-startup "mako"` directly after the `swayidle` line. After the edit, that block should read (line numbers may shift):

```kdl
spawn-at-startup "qs"
spawn-at-startup "swaybg" "-i" "/home/aru/Pictures/wallpapers/clouds.png" "-m" "fill"
spawn-at-startup "swayidle" "-w"
spawn-at-startup "mako"
```

- [ ] **Step 3: Verify config validity without restarting niri**

Run: `niri validate -c ~/dotfiles/niri/.config/niri/config.kdl 2>&1`
Expected: no errors. If `niri validate` is unavailable on this version, fall back to `niri msg action <noop>` — config is reloaded on edit by niri's file watcher; check `journalctl --user -u niri -n 30` for parse errors.

- [ ] **Step 4: Commit**

```bash
git add niri/.config/niri/config.kdl
git commit -m "niri: spawn mako on startup"
```

---

## Task 6: Create the `Notifications` singleton

**Files:**
- Create: `quickshell/.config/quickshell/Notifications.qml`

- [ ] **Step 1: Write the singleton**

Create `~/dotfiles/quickshell/.config/quickshell/Notifications.qml`:

```qml
pragma Singleton

import Quickshell
import Quickshell.Io

// mako DND state. dnd=true → mode=do-not-disturb (popups suppressed; history
// still accrues). Same shape as Radio.qml / SuspendInhibit.qml: re-probe on CC
// open, no periodic polling. `toggle` is optimistic; next `refresh` corrects
// if makoctl wasn't running.
Singleton {
    id: root
    property bool dnd: false

    function refresh() { modeGet.running = true; }
    function toggle() {
        modeToggle.command = ["makoctl", "mode", "-t", "do-not-disturb"];
        modeToggle.running = true;
        root.dnd = !root.dnd;
    }

    Process {
        id: modeGet
        command: ["sh", "-c", "makoctl mode 2>/dev/null | grep -q do-not-disturb && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "1" }
    }
    Process { id: modeToggle }
}
```

- [ ] **Step 2: Verify Quickshell parses it**

Quickshell hot-reloads on file change. If `qs` is already running, watch its stderr/journal for parse errors:

Run: `journalctl --user -e --since "1 minute ago" | grep -i quickshell | head -20`
Expected: no QML parse errors mentioning `Notifications.qml`. (Per [[reference-quickshell-stale-cache-errors]], live-reload is authoritative.)

- [ ] **Step 3: Confirm singleton is reachable**

There is no IPC binding for `Notifications` yet, so reach it indirectly via a temporary `qs ipc call` if you've wired one — or skip and let Task 7's wiring serve as the verification. Either is fine.

- [ ] **Step 4: Commit**

```bash
git add quickshell/.config/quickshell/Notifications.qml
git commit -m "quickshell: add Notifications singleton wrapping makoctl"
```

---

## Task 7: Insert "Quiet" row into ControlCenter

**Files:**
- Modify: `quickshell/.config/quickshell/ControlCenter.qml`

This task has many mechanical shifts. Apply them all in one edit, then verify in Task 8.

- [ ] **Step 1: Update the row-map comment at the top of the file**

In the header block (the comment table around lines 12–17), replace:

```
//   0 Brightness (slider)   5 BT (device picker)
//   1 Volume (slider)       6 Wifi (picker + password)
//   2 Airplane (toggle)     7 Output (sink picker)
//   3 Warm (toggle)         8 Power profile (EPP cycler)
//   4 Auto-suspend (toggle)
```

with:

```
//   0 Brightness (slider)   6 BT (device picker)
//   1 Volume (slider)       7 Wifi (picker + password)
//   2 Airplane (toggle)     8 Output (sink picker)
//   3 Warm (toggle)         9 Power profile (EPP cycler)
//   4 Auto-suspend (toggle)
//   5 Quiet (toggle — mako DND)
```

Then in the same header block, update the power-section comment from `(rows 9 & 10)` to `(rows 10 & 11)` and the wrap-group description from `{0..8}` / `{9,10}` to `{0..9}` / `{10,11}`.

- [ ] **Step 2: Bump `advanceRow`**

Replace:

```qml
function advanceRow(dir) {
    if (cc.focusedRow >= 9) {
        cc.focusedRow = 9 + ((cc.focusedRow - 9 + dir + 2) % 2);
    } else {
        cc.focusedRow = (cc.focusedRow + dir + 9) % 9;
    }
}
```

with:

```qml
function advanceRow(dir) {
    if (cc.focusedRow >= 10) {
        cc.focusedRow = 10 + ((cc.focusedRow - 10 + dir + 2) % 2);
    } else {
        cc.focusedRow = (cc.focusedRow + dir + 10) % 10;
    }
}
```

- [ ] **Step 3: Add `Notifications.refresh()` to `refresh()`**

Inside `function refresh() { … }`, append `Notifications.refresh();` after the existing calls.

- [ ] **Step 4: Bump `dispatchHL` switch**

Replace the `dispatchHL` body's cases with:

```qml
function dispatchHL(dir) {
    switch (cc.focusedRow) {
        case 0: Brightness.set(Brightness.value + dir * 5); break;
        case 1: cc.nudgeVolume(dir); break;
        case 2: Radio.toggleAirplane(); break;
        case 3: NightLight.toggle(); break;
        case 4: SuspendInhibit.toggle(); break;
        case 5: Notifications.toggle(); break;              // Quiet (mako DND)
        case 6: cc.openList(); break;                       // BT
        case 7: cc.openList(); break;                       // Wifi
        case 8: cc.openList(); break;                       // Output
        case 9: Power.cycle(dir); break;                    // Power profile
        case 10:
        case 11: {
            cc.disarm();
            cc.footerCol = (cc.footerCol + dir + 3) % 3;
            break;
        }
    }
}
```

- [ ] **Step 5: Bump `handleEnter` switch**

Replace its cases with:

```qml
function handleEnter() {
    switch (cc.focusedRow) {
        case 1: cc.toggleMute(); break;
        case 2: Radio.toggleAirplane(); break;
        case 3: NightLight.toggle(); break;
        case 4: SuspendInhibit.toggle(); break;
        case 5: Notifications.toggle(); break;              // Quiet (mako DND)
        case 6: cc.openList(); break;                       // BT
        case 7: cc.openList(); break;                       // Wifi
        case 8: cc.openList(); break;                       // Output
        case 9: Power.cycle(1); break;                      // Power profile
        case 10:
        case 11: cc.armOrFire(cc.focusedRow, cc.footerCol, (cc.focusedRow - 10) * 3 + cc.footerCol); break;
    }
}
```

- [ ] **Step 6: Bump `listLen` / `openList`**

Replace:

```qml
function listLen() {
    if (cc.openRow === 6) return WifiCtl.networks.length + 1;
    if (cc.openRow === 5) return BtCtl.devices.length + 1;
    if (cc.openRow === 7) return AudioCtl.sinks.length;
    return 0;
}
function openList() {
    cc.openRow = cc.focusedRow;
    cc.listSel = 0;
    if (cc.focusedRow === 6) WifiCtl.scan();
    if (cc.focusedRow === 5) BtCtl.scan();
}
```

with:

```qml
function listLen() {
    if (cc.openRow === 7) return WifiCtl.networks.length + 1;
    if (cc.openRow === 6) return BtCtl.devices.length + 1;
    if (cc.openRow === 8) return AudioCtl.sinks.length;
    return 0;
}
function openList() {
    cc.openRow = cc.focusedRow;
    cc.listSel = 0;
    if (cc.focusedRow === 7) WifiCtl.scan();
    if (cc.focusedRow === 6) BtCtl.scan();
}
```

- [ ] **Step 7: Bump `commitList`**

In `commitList`, replace:
- `if (cc.openRow === 6) {` → `if (cc.openRow === 7) {` (the Wifi branch)
- `} else if (cc.openRow === 5) {` → `} else if (cc.openRow === 6) {` (the BT branch)
- `} else if (cc.openRow === 7) {` → `} else if (cc.openRow === 8) {` (the Output branch)

All inner logic stays the same — the only change is the row numbers in the conditionals.

- [ ] **Step 8: Bump `Connections` openRow checks**

For each of the three `Connections` blocks (`WifiCtl`, `BtCtl`, `AudioCtl`):
- `cc.openRow === 6` → `cc.openRow === 7` (Wifi)
- `cc.openRow === 5` → `cc.openRow === 6` (BT)
- `cc.openRow === 7` → `cc.openRow === 8` (Output)

- [ ] **Step 9: Insert the new "Quiet" CcToggleRow + shift instantiation indices**

In the `Column { id: shell … }` block, between the Auto-suspend row (currently `rowIndex: 4`) and the BT row (currently `BtRow { rowIndex: 5 }`), insert:

```qml
// 5 — Quiet (mako DND)
CcToggleRow {
    cc: cc; rowIndex: 5; label: "Quiet"
    on: Notifications.dnd
    onToggled: Notifications.toggle()
}
```

Then, in the same `Column`, bump every subsequent `rowIndex`:
- `BtRow { cc: cc; rowIndex: 5 }` → `rowIndex: 6` (and update its leading `// 5 — BT …` comment to `// 6 — BT …`)
- `WifiRow { cc: cc; rowIndex: 6 }` → `rowIndex: 7` (comment `// 6` → `// 7`)
- `OutputRow { cc: cc; rowIndex: 7 }` → `rowIndex: 8` (comment `// 7` → `// 8`)
- `PowerRow { cc: cc; rowIndex: 8 }` → `rowIndex: 9` (comment `// 8` → `// 9`)
- The `Item { id: powerSection … }` comment block: `(rows 9 + 10)` → `(rows 10 + 11)`.
- Inside `powerColumn`: `PowerGridRow { rowIndex: 9; rowIdx: 0; … }` → `rowIndex: 10`; `PowerGridRow { rowIndex: 10; rowIdx: 1; … }` → `rowIndex: 11`. Update the adjacent comments `// 9 — Power session: …` → `// 10 — Power session: …` and `// 10 — Power system: …` → `// 11 — Power system: …`.

- [ ] **Step 10: Verify Quickshell live-reloads cleanly**

Save the file. Quickshell hot-reloads. Open the CC (existing bind, e.g. Super+Space).
Expected: CC opens, row 0 (Brightness) is focused. No QML parse error in `journalctl --user -e | grep -i quickshell`.

- [ ] **Step 11: Commit**

```bash
git add quickshell/.config/quickshell/ControlCenter.qml
git commit -m "cc: insert Quiet row at index 5, shift downstream rows"
```

---

## Task 8: End-to-end CC verification

**Files:** none (runtime verification).

- [ ] **Step 1: Start mako manually for this session**

Run: `pgrep -x mako >/dev/null || (mako &; disown)`
Expected: `pgrep -x mako` returns a PID. (Will be permanent after next niri restart, via the spawn-at-startup line.)

- [ ] **Step 2: Open CC, walk to row 5**

Open CC. Press `j` four times.
Expected: focus highlight rests on "Quiet". Label "Quiet" is left-justified at the 12px inset, switch widget at the right edge with the standard 22×12 track + 8×8 knob.

- [ ] **Step 3: Toggle on with H/L (or Enter)**

Press `l`.
Expected: switch flips to "on" (accentText fill, knob moves right). Verify externally:

Run: `makoctl mode`
Expected: `do-not-disturb` listed as active.

- [ ] **Step 4: Confirm DND suppresses popups**

Run: `notify-send "should be silent" "DND on"`
Expected: no popup appears. Verify it landed in history:

Run: `makoctl history | head -5`
Expected: the new notification is listed.

- [ ] **Step 5: Toggle off**

Press `l` again on row 5.
Expected: switch flips off; `makoctl mode` no longer shows `do-not-disturb`.

- [ ] **Step 6: Confirm popups resume**

Run: `notify-send "back" "popups on"`
Expected: popup appears in top-left, pixel-aligned with a niri window's outer-border corner.

- [ ] **Step 7: Verify downstream rows still work**

From CC, press `j` to walk through rows 6 (BT), 7 (Wifi), 8 (Output), 9 (Power profile). Open Wifi (`l` on row 7) and confirm the password flow still parses (does not need to actually connect).
Expected: every row reachable, BtRow/WifiRow/OutputRow/PowerRow render correctly, no row-index off-by-one symptoms (wrong row highlighted, wrong action firing).

- [ ] **Step 8: Verify power footer still works**

Press `Mod+Shift+E` (the power-section IPC).
Expected: power footer animates in; J/K wraps within rows 10/11; arm-then-confirm on `Lock` fires correctly (test only Lock — it's the safest).

- [ ] **Step 9: Stop the manual mako before next task**

Run: `pkill -x mako`
Expected: `pgrep -x mako` returns nothing. (niri will respawn it on next login.)

---

## Task 9: Update CONTEXT.md

**Files:**
- Modify: `CONTEXT.md`

- [ ] **Step 1: Locate the stack table and notification mention**

Run: `grep -nE 'swaync|notification|Stack' ~/dotfiles/CONTEXT.md | head -20`
Expected: a stack table around the top and a "not configured" mention for swaync somewhere.

- [ ] **Step 2: Replace the swaync mention**

Find the line/sentence describing swaync as "not configured" and replace it with a sentence pointing at mako:

> Notifications: mako (stow `mako/`, `~/.config/mako/config`). Top-left popups, Sky Paper theme, aligned with niri window outer-border corner. DND via CC row 5 "Quiet" / `makoctl mode -t do-not-disturb`. Spawn-at-startup from niri.

If swaync is in the Stack table, replace its row with a mako row of the same shape.

- [ ] **Step 3: Add `Notifications` to the singletons list**

Find the section listing Quickshell singletons (`Brightness`, `NightLight`, `Radio`, `WifiCtl`, `BtCtl`, `Power`, `SuspendInhibit`, `NiriIpc`, `PowerActions`, `AudioCtl`, `Theme`). Add `Notifications` — one-line description: "wraps `makoctl mode`; refreshed on CC open."

- [ ] **Step 4: Update the ControlCenter row map**

Find the CC row table in CONTEXT.md. Insert "5 Quiet (mako DND)" between Auto-suspend and BT and bump the remaining rows 5→6, 6→7, 7→8, 8→9, 9→10, 10→11.

- [ ] **Step 5: Commit**

```bash
git add CONTEXT.md
git commit -m "context: document mako + Notifications singleton + Quiet row"
```

---

## Task 10: Mark todos.txt #2 done

**Files:**
- Modify: `todos.txt`

- [ ] **Step 1: Flip the status tag on item 2**

Open `~/dotfiles/todos.txt`. Find the `[next] 2. notifications — swaync (or mako)` line and change the status tag from `[next]` to `[done]`. Leave the body intact for history (matches how prior items are recorded).

- [ ] **Step 2: Commit**

```bash
git add todos.txt
git commit -m "todos: mark #2 notifications done"
```

---

## Task 11: Fresh-login validation

**Files:** none (runtime verification).

- [ ] **Step 1: Log out and back in (or restart niri-session)**

This ensures `spawn-at-startup "mako"` actually fires.

- [ ] **Step 2: Confirm mako is running**

Run: `pgrep -x mako`
Expected: a PID. If absent: check `journalctl --user -e --since "5 minutes ago"` for niri spawn errors.

- [ ] **Step 3: Smoke-test once more**

Run: `notify-send "fresh login" "mako ready"`
Expected: popup renders, palette correct, top-left alignment correct.

- [ ] **Step 4: Confirm `pacman -Qi mako` reports installed**

Run: `pacman -Qi mako | head -2`
Expected: package name + version.

---

## Task 12: Merge back into laniakea

**Files:** none (git only).

Per project memory ([[feedback-no-commits-no-branch-changes]]): laniakea is only touched via merge, never direct commits.

- [ ] **Step 1: Confirm branch is green**

All previous tasks' verification steps passed.

- [ ] **Step 2: Switch to laniakea and merge**

Run: `git switch laniakea && git merge --ff-only mako-notifications`
Expected: fast-forward merge succeeds (no merge commit needed since laniakea hasn't moved). If FF fails, investigate divergence — do NOT force-merge.

- [ ] **Step 3: Delete the feature branch**

Run: `git branch -d mako-notifications`
Expected: branch deleted; only `laniakea` (and any other in-flight branches) remain.

- [ ] **Step 4: Verify final state**

Run: `git log --oneline -5`
Expected: top 5 commits are the mako/notifications work in order.
