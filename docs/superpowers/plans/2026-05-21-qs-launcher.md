# qs-launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A qs-native app launcher (apps + run + calc) that opens instantly from the bar center with a clock→Δ→input animation, replacing tofi.

**Architecture:** A backend singleton `AppLauncher.qml` (app model, fuzzy match, frecency, calc, run) feeds a view `Launcher.qml` (`PopupWindow` + `Field` + `ListView`). `Launcher` is declared inside `Bar.qml` next to `ControlCenter` so the bar's `Clock` can cross-fade on `launcher.visible`. The Δ-slides-left + field-grow animation lives inside the popup; the bar only fades its clock. Opens via `Mod+D` → `qs ipc call launcher toggle` against the resident `qs` process (no cold-start).

**Tech Stack:** Quickshell 0.3.0 (QtQuick, Quickshell.Io, Quickshell.Wayland), niri, GNU Stow. No test harness — verification is live-reload (`qs` auto-reloads on save) + `qs ipc` + `console.log` probes read from the `qs` stderr/journal.

**Conventions / gotchas baked into this plan:**
- After creating any new `.qml` file, `touch shell.qml` so live-reload regenerates qmldir (qmldir-stale gotcha).
- Live-reload validates parse correctness; do NOT `kill && restart qs` to "check" — that surfaces false stale-cache errors. Edit + save + watch the running instance.
- `onVisibleChanged` resets focus synchronously — call `forceActiveFocus()` AFTER `visible = true`.
- No `eval`/`Function` for calc — hand-rolled shunting-yard parser (V4 quirks memory).
- Bar glyphs must be core-Terminus letters — `Δ` is crisp; do not swap to Unicode/Nerd icons.
- All paths absolute under `/home/aru` (repo convention).

---

## File Structure

- **Create** `quickshell/.config/quickshell/AppLauncher.qml` — `pragma Singleton`. App model wrapping `DesktopEntries`, `query`→`results`, fuzzy scorer, frecency load/save, calc parser, `launch`/`run`/`copy` actions.
- **Create** `quickshell/.config/quickshell/Launcher.qml` — `PopupWindow` view: box, `Field` + Δ adornment, `ListView`, open/close + slide animations, key dispatch, `IpcHandler`.
- **Modify** `quickshell/.config/quickshell/Bar.qml` — declare `Launcher { id: launcher; anchorWin: bar }`; make `Clock` cross-fade on `launcher.visible`.
- **Modify** `quickshell/.config/quickshell/Theme.qml` — add `launcherGlyph` token.
- **Modify** `quickshell/.config/quickshell/shell.qml` — `touch` only (no structural change; Launcher lives in Bar). Used to force qmldir regen.
- **Modify** `niri/.config/niri/config.kdl:447` — rebind `Mod+D`.
- **Delete** `tofi/` (stow package) + remove pacman pkg.
- **Modify** `CONTEXT.md`, `PALETTE.md`, `todos.txt` — doc updates.

---

## Task 1: AppLauncher singleton — app model + fuzzy match (alpha order)

Backend first, ranked alphabetically (frecency added in Task 7). No UI yet; verified by `console.log`.

**Files:**
- Create: `quickshell/.config/quickshell/AppLauncher.qml`
- Modify: `quickshell/.config/quickshell/shell.qml` (touch)

- [ ] **Step 1: Create the singleton with app list + fuzzy scorer**

Create `quickshell/.config/quickshell/AppLauncher.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell

// Launcher backend. Owns the app list, fuzzy matching, and (Task 5/6/7)
// calc + run-fallback + frecency. View layer is Launcher.qml.
Singleton {
    id: root

    // current search text, driven by the Field in Launcher.qml
    property string query: ""

    // computed result rows. Each row: { kind, label, sub, entry }
    //   kind: "app" | "calc" | "run"   (calc/run added in later tasks)
    //   entry: the DesktopEntry for "app" rows, else null
    property var results: computeResults()

    onQueryChanged: results = computeResults()

    // --- app inventory -----------------------------------------------------
    // DesktopEntries.applications is an UntypedObjectModel; .values is the
    // JS array of DesktopEntry. Filter out noDisplay (hidden) entries.
    function apps() {
        var out = [];
        var vals = DesktopEntries.applications.values;
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i];
            if (e && !e.noDisplay && e.name) out.push(e);
        }
        return out;
    }

    // --- fuzzy subsequence scorer -----------------------------------------
    // Returns -1 if `q` is not a subsequence of `t`, else a score where
    // contiguous runs and early/word-start matches score higher.
    function fuzzyScore(q, t) {
        q = q.toLowerCase();
        t = t.toLowerCase();
        if (q.length === 0) return 0;
        var ti = 0, score = 0, streak = 0, firstIdx = -1, prevIdx = -2;
        for (var qi = 0; qi < q.length; qi++) {
            var c = q.charAt(qi);
            var found = -1;
            for (; ti < t.length; ti++) {
                if (t.charAt(ti) === c) { found = ti; break; }
            }
            if (found === -1) return -1;
            if (firstIdx === -1) firstIdx = found;
            if (found === prevIdx + 1) { streak++; score += 5 + streak; }
            else { streak = 0; score += 1; }
            // word-start bonus (start of string or preceded by space/-/.)
            if (found === 0) score += 8;
            else {
                var pc = t.charAt(found - 1);
                if (pc === " " || pc === "-" || pc === ".") score += 4;
            }
            prevIdx = found;
            ti = found + 1;
        }
        score += Math.max(0, 10 - firstIdx);
        return score;
    }

    // --- result computation (Task 1: apps only, alpha-tiebreak) -----------
    function computeResults() {
        var q = root.query.trim();
        if (q.length === 0) return [];   // empty until you type
        var list = apps();
        var scored = [];
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            var s = fuzzyScore(q, e.name);
            if (s < 0) continue;
            scored.push({ kind: "app", label: e.name, sub: e.comment || "",
                          entry: e, score: s });
        }
        scored.sort(function (a, b) {
            if (b.score !== a.score) return b.score - a.score;
            return a.label.localeCompare(b.label);
        });
        return scored;
    }

    // --- actions -----------------------------------------------------------
    function launch(row) {
        if (row && row.entry) row.entry.execute();
    }
}
```

- [ ] **Step 2: Register the singleton in qmldir**

Quickshell auto-generates qmldir, but new files need a nudge. Run:

```bash
touch /home/aru/dotfiles/quickshell/.config/quickshell/shell.qml
```

- [ ] **Step 3: Add a temporary probe to verify the model loads**

Temporarily append to `shell.qml` inside the `Scope` (remove in Step 5):

```qml
    Component.onCompleted: {
        console.log("APPLAUNCHER probe: total apps =", AppLauncher.apps().length);
        AppLauncher.query = "fire";
        console.log("APPLAUNCHER probe: 'fire' results =",
            JSON.stringify(AppLauncher.results.map(function (r) { return r.label; })));
    }
```

- [ ] **Step 4: Verify via live-reload**

Save; the resident `qs` reloads. Read its stderr/journal:

```bash
journalctl --user -n 30 --no-pager 2>/dev/null | grep APPLAUNCHER || echo "check the terminal qs is running in"
```

Expected: `total apps =` a plausible count (>10), and `'fire' results` includes Firefox (and nothing without an `f…i…r…e` subsequence). If `total apps = 0`, `DesktopEntries` import is wrong — it's in the base `Quickshell` module (already imported).

- [ ] **Step 5: Remove the probe**

Delete the `Component.onCompleted` block added in Step 3 from `shell.qml`.

- [ ] **Step 6: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/AppLauncher.qml quickshell/.config/quickshell/shell.qml
git commit -m "quickshell: AppLauncher singleton — app model + fuzzy match

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Launcher view — popup, field, list, IPC, niri bind

A working launcher: `Mod+D` opens a centered popup, type to filter, arrows/Tab to move, Enter launches, Esc closes. No fancy animation yet (added Task 3/4).

**Files:**
- Create: `quickshell/.config/quickshell/Launcher.qml`
- Modify: `quickshell/.config/quickshell/Bar.qml`
- Modify: `niri/.config/niri/config.kdl:447`

- [ ] **Step 1: Create Launcher.qml (static layout + keys + IPC)**

Create `quickshell/.config/quickshell/Launcher.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io

// App launcher popup. Backend logic lives in AppLauncher (singleton).
// Opens centered under the bar; type to filter, arrows/Tab to move,
// Enter to launch, Esc to close.
//
// The input is inlined (not Field.qml) on purpose: nav keys (Up/Down/Tab)
// are handled on the focused TextInput itself so it can intercept them
// before its default cursor/focus-traversal behavior, while printable keys
// fall through (event.accepted left false) and type normally.
PopupWindow {
    id: launcher

    property var anchorWin

    anchor.window: anchorWin
    anchor.rect.x: anchorWin ? Math.round((anchorWin.width - launcher.width) / 2) : 0
    anchor.rect.y: anchorWin ? anchorWin.height : 0
    implicitWidth: 420
    implicitHeight: box.implicitHeight
    visible: false
    grabFocus: true
    color: "transparent"

    property int sel: 0
    property bool closing: false

    // live-filter feeds the singleton; reset selection on every change
    function setQuery(q) { AppLauncher.query = q; launcher.sel = 0; }

    function open()  { closing = false; visible = true; }
    function close() { if (!visible || closing) return; visible = false; }
    property double lastToggle: 0
    function toggle() {
        var now = Date.now();
        if (now - lastToggle < 200) return;
        lastToggle = now;
        visible ? close() : open();
    }

    onVisibleChanged: if (visible) {
        input.text = "";
        AppLauncher.query = "";
        launcher.sel = 0;
        input.forceActiveFocus();   // AFTER visible flip
    }

    function move(dir) {
        var n = AppLauncher.results.length;
        if (n <= 0) { launcher.sel = 0; return; }
        launcher.sel = (launcher.sel + dir + n) % n;
    }
    function commit() {
        var row = AppLauncher.results[launcher.sel];
        if (!row) return;
        AppLauncher.launch(row);
        launcher.close();
    }

    Rectangle {
        id: box
        anchors.top: parent.top
        anchors.left: parent.left
        width: launcher.width
        implicitHeight: inputRow.height + list.height + 12
        color: Theme.boxFill
        border.width: 1
        border.color: Theme.accentSoft
        radius: 0

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            // input row: Δ glyph + `>` prompt + TextInput
            Item {
                id: inputRow
                width: parent.width
                height: 28

                Text {
                    id: glyph
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.launcherGlyph
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.hintingPreference: Font.PreferFullHinting
                    renderType: Text.NativeRendering
                }

                Text {
                    id: prompt
                    anchors.left: glyph.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: input.activeFocus ? Theme.accentText : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.hintingPreference: Font.PreferFullHinting
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: input
                    anchors.left: prompt.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.hintingPreference: Font.PreferFullHinting
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    clip: true
                    onTextChanged: launcher.setQuery(text)

                    // nav keys intercepted here; printable keys fall through
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            launcher.close(); event.accepted = true;
                        } else if (event.key === Qt.Key_Down
                                   || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                            launcher.move(+1); event.accepted = true;
                        } else if (event.key === Qt.Key_Up
                                   || event.key === Qt.Key_Backtab
                                   || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                            launcher.move(-1); event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launcher.commit(); event.accepted = true;
                        }
                        // everything else: accepted stays false → types normally
                    }
                }
            }

            // results
            ListView {
                id: list
                width: parent.width
                height: Math.min(count, 5) * 24
                clip: true
                interactive: false
                model: AppLauncher.results
                currentIndex: launcher.sel
                delegate: Rectangle {
                    width: list.width
                    height: 24
                    color: index === launcher.sel ? Theme.accentSoft : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.hintingPreference: Font.PreferFullHinting
                        renderType: Text.NativeRendering
                        elide: Text.ElideRight
                        width: list.width - 16
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { launcher.sel = index; launcher.commit(); }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle(); }
        function open(): void { launcher.open(); }
        function close(): void { launcher.close(); }
    }
}
```

Note: `Field.qml`'s `text` is an alias to its `TextInput.text`; binding `onTextChanged` here fires on every keystroke. `field.input` exposes the inner `TextInput` for focus.

- [ ] **Step 2: Declare Launcher in Bar.qml**

In `quickshell/.config/quickshell/Bar.qml`, just after the `ControlCenter { id: cc; anchorWin: bar }` block (around line 80-83), add:

```qml
    Launcher {
        id: launcher
        anchorWin: bar
    }
```

- [ ] **Step 3: Force qmldir regen**

```bash
touch /home/aru/dotfiles/quickshell/.config/quickshell/shell.qml
```

- [ ] **Step 4: Rebind Mod+D in niri**

In `niri/.config/niri/config.kdl` line 447, replace:

```kdl
    Mod+D hotkey-overlay-title="Run an Application: tofi" { spawn "tofi-drun"; }
```

with:

```kdl
    Mod+D hotkey-overlay-title="Run an Application" { spawn "qs" "ipc" "call" "launcher" "toggle"; }
```

Reload niri config: `niri msg action load-config-file` (or it auto-reloads on save).

- [ ] **Step 5: Verify the full open→type→launch→close loop**

1. Press `Mod+D` → centered popup appears under the bar, empty, cursor in field.
2. Type `fire` → Firefox appears in the list, highlighted.
3. `Down`/`Tab` and `Up`/`Shift+Tab` move the highlight (wraps).
4. `Enter` launches the highlighted app and the popup closes.
5. `Mod+D` then `Esc` closes without launching.

If the popup opens but arrows/Tab move the text cursor instead of the list selection, confirm the `Keys.onPressed` is on the `input` `TextInput` (not the box) and sets `event.accepted = true` for nav keys. If nothing opens, run `qs ipc call launcher toggle` manually and check for IPC errors.

- [ ] **Step 6: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/Launcher.qml quickshell/.config/quickshell/Bar.qml niri/.config/niri/config.kdl quickshell/.config/quickshell/shell.qml
git commit -m "quickshell: Launcher view + IPC, Mod+D rebind to qs launcher

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Bar glyph + clock cross-fade

Add the `Δ` token and make the bar clock fade out while the launcher is open, so the center reads as "handed over" to the launcher.

**Files:**
- Modify: `quickshell/.config/quickshell/Theme.qml`
- Modify: `quickshell/.config/quickshell/Bar.qml`

- [ ] **Step 1: Add the glyph token**

In `quickshell/.config/quickshell/Theme.qml`, after the `cellSize` line (line 36), add:

```qml

    // launcher glyph — paired with the CC's λ. Core-Terminus letter (crisp).
    readonly property string launcherGlyph: "Δ";
```

- [ ] **Step 2: Cross-fade the clock on launcher.visible**

In `Bar.qml`, the `Clock { id: clockMod; … }` block (lines 33-37) gets an opacity binding + behavior. Replace it with:

```qml
    // center — clock. Fades out while the launcher owns the center.
    Clock {
        id: clockMod
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: launcher.visible ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
```

- [ ] **Step 3: Verify**

Press `Mod+D`: the clock fades out (~160ms) as the popup appears; `Esc`: clock fades back in. The fade should feel coordinated with the popup, not abrupt.

- [ ] **Step 4: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/Theme.qml quickshell/.config/quickshell/Bar.qml
git commit -m "quickshell: Δ launcher glyph token + clock cross-fade on open

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Open animation — Δ slides left, field grows, list expands

The "beautiful" part. On open: Δ animates from row-center to the left edge while the field width grows 0→full and the prompt fades in; the result list height animates with the row count (max 5). On close: reverse, then hide.

**Files:**
- Modify: `quickshell/.config/quickshell/Launcher.qml`

- [ ] **Step 1: Add an animation progress property + drive the open/close**

In `Launcher.qml`, replace the `open()` / `close()` / `toggle()` functions and add an `anim` property + animations. Replace:

```qml
    function open()  { closing = false; visible = true; }
    function close() { if (!visible || closing) return; visible = false; }
```

with:

```qml
    // 0 = fully closed (Δ centered, field collapsed), 1 = fully open
    property real anim: 0

    function open()  { closing = false; visible = true; openAnim.restart(); }
    function close() {
        if (!visible || closing) return;
        closing = true;
        closeAnim.restart();
    }

    NumberAnimation {
        id: openAnim
        target: launcher; property: "anim"; to: 1
        duration: 220; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: closeAnim
        target: launcher; property: "anim"; to: 0
        duration: 200; easing.type: Easing.InCubic
        onFinished: { launcher.visible = false; launcher.closing = false; }
    }
```

- [ ] **Step 2: Animate the glyph position, prompt + input fade-in**

In the `inputRow` `Item`, drive the glyph from center→left by `anim`, and fade the prompt + input in. The `prompt` and `input` keep their anchors relative to `glyph.right`, so they follow the glyph as it slides and just fade with `anim`.

Change the `glyph` `Text`: remove its `anchors.left`/`anchors.leftMargin` and give it an animated `x` (centered at `anim 0`, pinned left at `anim 1`):

```qml
                Text {
                    id: glyph
                    // anim 0: horizontally centered; anim 1: pinned to left (x=4)
                    x: 4 + (1 - launcher.anim) * Math.round((inputRow.width - width) / 2 - 4)
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.launcherGlyph
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.hintingPreference: Font.PreferFullHinting
                    renderType: Text.NativeRendering
                }
```

Add `opacity: launcher.anim` to BOTH the `prompt` `Text` and the `input` `TextInput` so they fade in as the glyph reaches the left edge:

```qml
                // on the `prompt` Text, add:
                    opacity: launcher.anim
                // on the `input` TextInput, add:
                    opacity: launcher.anim
```

Because `prompt.anchors.left: glyph.right` and `input.anchors.left: prompt.right`, the whole `> text` group rides along as `glyph.x` animates from center to left — giving the "Δ slides left, input unfurls to its right" effect without manual width math.

- [ ] **Step 3: Animate the list height + box opacity**

Replace the `ListView`'s `height` line and add a fade so results don't pop. Change:

```qml
                height: Math.min(count, 5) * 24
```

to:

```qml
                height: Math.min(count, 5) * 24 * launcher.anim
                opacity: launcher.anim
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
```

The `Behavior` smooths height changes as you type (results appearing/disappearing); the `* launcher.anim` factor collapses it during open/close.

- [ ] **Step 4: Verify the choreography**

`Mod+D`: Δ starts centered, glides left as the field unrolls to the right; start typing and the list grows downward smoothly (capped at 5 rows), expanding/contracting as matches change. `Esc`: everything retracts (list collapses, field rolls up, Δ returns toward center) then the window hides. No flicker, no popping rows.

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/Launcher.qml
git commit -m "quickshell: launcher open animation — Δ slide-left, field grow, list expand

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Calculator mode (auto-detected)

When the query is pure arithmetic with an operator, show one result row with the value; Enter copies it via `wl-copy`. Hand-rolled parser (no eval).

**Files:**
- Modify: `quickshell/.config/quickshell/AppLauncher.qml`

- [ ] **Step 1: Add the calc detector + shunting-yard evaluator**

In `AppLauncher.qml`, add these functions (above `computeResults`):

```qml
    // calc is active iff the trimmed query is pure arithmetic AND has an
    // operator. Bare numbers ("2048") stay app-search.
    function isCalc(s) {
        var t = s.trim();
        if (t.length === 0) return false;
        if (!/^[0-9.+\-*/%() ]+$/.test(t)) return false;
        return /[+\-*/%]/.test(t);
    }

    // Shunting-yard → RPN → evaluate. Returns a Number or null on error.
    // No eval/Function (Qt V4 quirks). Unary minus handled via prevType.
    function evalCalc(s) {
        var t = s.trim();
        if (!/^[0-9.+\-*/%() ]+$/.test(t)) return null;
        var tokens = t.match(/(\d+\.?\d*|\.\d+|[+\-*/%()])/g);
        if (!tokens) return null;
        var prec = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "u-": 3 };
        var out = [], ops = [], prev = "op";  // "op" | "num" | ")"
        for (var i = 0; i < tokens.length; i++) {
            var tk = tokens[i];
            if (/^[\d.]/.test(tk)) { out.push(parseFloat(tk)); prev = "num"; }
            else if (tk === "(") { ops.push(tk); prev = "op"; }
            else if (tk === ")") {
                while (ops.length && ops[ops.length - 1] !== "(") out.push(ops.pop());
                if (!ops.length) return null;
                ops.pop();
                prev = ")";
            } else {
                var op = tk;
                if (op === "-" && (prev === "op")) op = "u-";   // unary minus
                while (ops.length) {
                    var top = ops[ops.length - 1];
                    if (top === "(") break;
                    if (prec[top] >= prec[op] && op !== "u-") out.push(ops.pop());
                    else break;
                }
                ops.push(op);
                prev = "op";
            }
        }
        while (ops.length) {
            var o = ops.pop();
            if (o === "(") return null;
            out.push(o);
        }
        var st = [];
        for (var j = 0; j < out.length; j++) {
            var x = out[j];
            if (typeof x === "number") { st.push(x); continue; }
            if (x === "u-") { if (!st.length) return null; st.push(-st.pop()); continue; }
            if (st.length < 2) return null;
            var b = st.pop(), a = st.pop();
            if (x === "+") st.push(a + b);
            else if (x === "-") st.push(a - b);
            else if (x === "*") st.push(a * b);
            else if (x === "/") st.push(a / b);
            else if (x === "%") st.push(a % b);
        }
        if (st.length !== 1) return null;
        var r = st[0];
        if (typeof r !== "number" || !isFinite(r)) return null;
        return Math.round(r * 1e6) / 1e6;   // trim float noise
    }
```

- [ ] **Step 2: Branch computeResults on calc**

In `AppLauncher.qml`, at the top of `computeResults()`, before the apps loop, add:

```qml
        if (isCalc(root.query)) {
            var v = evalCalc(root.query);
            if (v === null) return [];
            return [{ kind: "calc", label: String(v), sub: "= copy", entry: null }];
        }
```

- [ ] **Step 3: Add the copy action + route commit**

Add a copy action to `AppLauncher.qml` using `Quickshell.Io.Process`. First add the import at top:

```qml
import Quickshell.Io
```

Then add inside the `Singleton`:

```qml
    Process { id: copyProc }
    function copy(text) {
        copyProc.command = ["wl-copy", "--", String(text)];
        copyProc.running = true;
    }
```

- [ ] **Step 4: Route commit() in Launcher.qml by row kind**

In `Launcher.qml`, replace `commit()`:

```qml
    function commit() {
        var row = AppLauncher.results[launcher.sel];
        if (!row) return;
        if (row.kind === "calc") AppLauncher.copy(row.label);
        else AppLauncher.launch(row);
        launcher.close();
    }
```

- [ ] **Step 5: Show the calc sub-label in the delegate (optional polish)**

In the list delegate, the existing `text: modelData.label` already shows the value. No change required; the `sub` field is available if a second line is wanted later. Skip.

- [ ] **Step 6: Verify**

- `1414+2313` → one row `3727`; `Enter` → check clipboard: `wl-paste` prints `3727`.
- `(2+3)*4` → `20`. `10/4` → `2.5`. `2*-3` → `-6`.
- `2048` → still the app search (no calc row). `7-zip` → app search.
- `1+` (incomplete) → empty list (no crash).

Run after testing: `wl-paste` to confirm the last copy.

- [ ] **Step 7: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/AppLauncher.qml quickshell/.config/quickshell/Launcher.qml
git commit -m "quickshell: launcher calc mode — auto-detect arithmetic, Enter copies

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Run-command fallback

When a non-empty query matches no app (and isn't calc), show one `» run: <query>` row that executes via `sh -c`.

**Files:**
- Modify: `quickshell/.config/quickshell/AppLauncher.qml`
- Modify: `quickshell/.config/quickshell/Launcher.qml`

- [ ] **Step 1: Append the run-fallback row in computeResults**

In `AppLauncher.qml` `computeResults()`, after the apps loop sorts `scored`, replace `return scored;` with:

```qml
        if (scored.length === 0 && q.length > 0) {
            return [{ kind: "run", label: "» run: " + q, sub: "", entry: null,
                      cmd: q }];
        }
        return scored;
```

- [ ] **Step 2: Add the run action**

In `AppLauncher.qml`, add:

```qml
    Process { id: runProc }
    function run(cmd) {
        runProc.command = ["sh", "-c", String(cmd)];
        runProc.running = true;
    }
```

- [ ] **Step 3: Route commit() for run rows**

In `Launcher.qml` `commit()`, extend the branch:

```qml
    function commit() {
        var row = AppLauncher.results[launcher.sel];
        if (!row) return;
        if (row.kind === "calc") AppLauncher.copy(row.label);
        else if (row.kind === "run") AppLauncher.run(row.cmd);
        else AppLauncher.launch(row);
        launcher.close();
    }
```

- [ ] **Step 4: Verify**

- Type a non-app string, e.g. `notify-send hi` → one row `» run: notify-send hi`; `Enter` → the notification fires (mako shows it).
- Type `fire` → still the app list (Firefox), no run row.
- Empty query → empty list (no run row).

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/AppLauncher.qml quickshell/.config/quickshell/Launcher.qml
git commit -m "quickshell: launcher run-command fallback for unmatched queries

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Frecency ranking + persistence

Persist launch history and blend it into the app ranking so frequently/recently used apps float up.

**Files:**
- Modify: `quickshell/.config/quickshell/AppLauncher.qml`

- [ ] **Step 1: Ensure the state dir exists + add FileView**

In `AppLauncher.qml`, add (state dir created once via Process; FileView reads the JSON):

```qml
    // frecency: { "<appId>": { count: N, last: <epochMs> } }
    property var frecency: ({})

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", "/home/aru/.local/state/quickshell"]
        Component.onCompleted: running = true
    }

    FileView {
        id: frecencyFile
        path: "/home/aru/.local/state/quickshell/launcher-frecency.json"
        blockLoading: true
        onLoaded: {
            try { root.frecency = JSON.parse(frecencyFile.text() || "{}"); }
            catch (e) { root.frecency = ({}); }
            root.results = root.computeResults();
        }
        onLoadFailed: root.frecency = ({})
    }
```

- [ ] **Step 2: Add the frecency boost + fold into ranking**

In `AppLauncher.qml`, add a boost function:

```qml
    // frequency × recency. Recent + frequent apps score highest.
    function frecencyBoost(id) {
        var rec = root.frecency[id];
        if (!rec) return 0;
        var ageDays = (Date.now() - rec.last) / 86400000;
        var w = ageDays < 1 ? 4 : ageDays < 7 ? 2 : ageDays < 30 ? 1 : 0.5;
        return rec.count * w;
    }
```

In `computeResults()`, change the app push to include the boost in `score`:

```qml
            scored.push({ kind: "app", label: e.name, sub: e.comment || "",
                          entry: e, score: s + frecencyBoost(e.id) * 3 });
```

(The `* 3` weights frecency enough to reorder near-equal fuzzy matches without overriding a clearly-better text match. Tune to taste.)

- [ ] **Step 3: Record + persist on launch**

In `AppLauncher.qml`, change `launch()` to bump frecency then save:

```qml
    function launch(row) {
        if (!row || !row.entry) return;
        var id = row.entry.id;
        var rec = root.frecency[id] || { count: 0, last: 0 };
        rec.count += 1;
        rec.last = Date.now();
        root.frecency[id] = rec;
        frecencyFile.setText(JSON.stringify(root.frecency));
        row.entry.execute();
    }
```

- [ ] **Step 4: Verify persistence + ranking**

1. Launch a mid-list app (say `gimp`) via the launcher a few times.
2. `cat /home/aru/.local/state/quickshell/launcher-frecency.json` → shows `gimp.desktop` (or its id) with `count` and `last`.
3. Open the launcher, type a short ambiguous prefix that matches gimp and others → gimp now ranks above equally-fuzzy alternatives.
4. `qs` reload (save any shell file) → re-open launcher; the boost persists (file is re-read on load).

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/AppLauncher.qml
git commit -m "quickshell: launcher frecency ranking + JSON persistence

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Remove tofi + update docs

Now that `Mod+D` is the qs launcher, remove tofi entirely and update the docs.

**Files:**
- Delete: `tofi/` (stow package)
- Modify: `CONTEXT.md`, `PALETTE.md`, `todos.txt`

- [ ] **Step 1: Confirm nothing else references tofi**

```bash
cd /home/aru/dotfiles
grep -rn "tofi" --include="*.kdl" --include="*.sh" --include="*.fish" . | grep -v "\.git/"
```

Expected: no remaining functional references (only doc mentions in CONTEXT/PALETTE/todos, handled below). If a niri/script reference remains, fix it before deleting.

- [ ] **Step 2: Unstow and remove the tofi package**

```bash
cd /home/aru/dotfiles
stow -D tofi          # removes the ~/.config/tofi symlink cleanly
rm -rf tofi           # remove the package from the repo
ls ~/.config/tofi 2>&1 || echo "symlink gone — good"
```

(Use `stow -D` — do NOT `rm` through the `~/.config/tofi` symlink, per the symlink-clobber gotcha.)

- [ ] **Step 3: Remove the pacman package**

```bash
sudo pacman -Rns tofi
pacman -Qi tofi 2>&1 | head -1   # expect: "error: package 'tofi' was not found"
```

- [ ] **Step 4: Update CONTEXT.md**

In `CONTEXT.md`:
- Replace the `tofi` Stack-table row (line ~281) with a `launcher` row describing the qs launcher: `quickshell-native (Launcher.qml + AppLauncher singleton). Mod+D → qs ipc call launcher toggle. Δ glyph slides from bar center, fuzzy+frecency, apps/run/calc. Replaced tofi 2026-05-21.`
- In the "Актуальные на laniakea" stow list (line ~295), remove `tofi`.

- [ ] **Step 5: Update PALETTE.md**

In `PALETTE.md`, replace the `**tofi:**` section (lines ~116-122) with a `**launcher:**` section: `boxFill bg, 1px accentSoft border, square corners, Terminess ${Theme.fontSize}px, Δ glyph accentText, selection bg accentSoft.`

- [ ] **Step 6: Update todos.txt #4**

In `todos.txt`, change the `[next] 4.` header to `[done 2026-05-21] 4.` and add a one-line note under it: `Built qs-native launcher (Launcher.qml + AppLauncher singleton) instead of the tofi ladder — resident qs = no cold-start. Apps+run+calc, fuzzy+frecency, Δ-slide animation. tofi removed.`

- [ ] **Step 7: Verify end-to-end one more time**

- `Mod+D` opens the launcher (tofi gone, no error).
- App launch, calc, run all work.
- `pacman -Qi tofi` → not installed; `~/dotfiles/tofi/` gone; `~/.config/tofi` symlink gone.

- [ ] **Step 8: Commit**

```bash
cd /home/aru/dotfiles
git add -A
git commit -m "tofi: remove — replaced by qs-native launcher; docs updated

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Final verification (whole feature)

- [ ] `Mod+D` opens instantly (no perceptible delay), centered under the bar, empty.
- [ ] Clock fades out on open, back in on close; Δ slides center→left as the field grows; list expands downward (≤5 rows) and animates as matches change.
- [ ] Typing filters live; arrows/Tab navigate (wrap); Enter launches; Esc closes.
- [ ] `1414+2313` → `3727`, Enter copies (`wl-paste` confirms); `2048` still searches apps.
- [ ] Unmatched query → `» run:` row executes via `sh -c`.
- [ ] Frecency file grows on launch and reorders results across `qs` reloads.
- [ ] `pacman -Qi tofi` → not installed; tofi package + symlink gone; CONTEXT/PALETTE/todos updated.
- [ ] `qs` running clean — no QML parse errors in its log, no leaked `qs`/Process instances (`pgrep -af qs`).

## Merge

Per repo policy (no direct commits to `laniakea`): once Final verification passes on the live system, merge `qs-launcher` → `laniakea` (fast-forward or `--no-ff` per preference), then delete the feature branch.
