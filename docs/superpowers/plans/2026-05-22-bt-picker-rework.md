# Bluetooth Picker Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Control Center Bluetooth picker toggle instantly, order paired/in-range devices first, distinguish paired-available from paired-unavailable, and add a manual re-scan trigger.

**Architecture:** `BtCtl.qml` (BlueZ backend singleton) gains an `inRangeMacs` property fed by parsing the scan stream's `RSSI:` lines, optimistic power-toggle state, and a tiered/sorted `devices` list. `BtRow.qml` dims out-of-range paired rows and adds a header re-scan glyph. `ControlCenter.qml` binds `r` to re-scan while the BT picker is open.

**Tech Stack:** Quickshell / QML (Qt 6, V4 JS engine), `bluetoothctl`. No unit-test harness — verification is QML load + live-reload behavior (per the project's stale-cache note: live-reload is fine; to validate a file from scratch, kill `qs` and clear the cache).

**Branch:** `bt-picker-rework` (already checked out — do not touch `laniakea`).

---

### Task 1: BtCtl backend — in-range tracking, optimistic toggle, tiered sort

**Files:**
- Modify: `quickshell/.config/quickshell/BtCtl.qml`

- [ ] **Step 1: Add the `inRangeMacs` property**

In the property block near the top (after `property bool _wantScan: false` at line 30), add:

```qml
    property var inRangeMacs: []        // MACs that reported RSSI in latest scan
```

- [ ] **Step 2: Replace the `devices` computed property with a tiered+sorted version**

Replace the existing block (lines 32-39):

```qml
    // [{mac, name, paired, connected}] — recomputed when any set changes
    readonly property var devices: _raw.map(function (d) {
        return {
            mac: d.mac, name: d.name,
            paired: root.pairedMacs.indexOf(d.mac) >= 0,
            connected: root.connectedMacs.indexOf(d.mac) >= 0
        };
    })
```

with:

```qml
    // [{mac, name, paired, connected, inRange}] sorted into three tiers:
    // (1) paired & in-range, (2) paired & out-of-range, (3) unpaired —
    // connected-first then by name within each tier. Recomputed when any
    // referenced set changes (deps captured via the function args).
    readonly property var devices: root._buildDevices(
        root._raw, root.pairedMacs, root.connectedMacs, root.inRangeMacs)

    function _buildDevices(raw, paired, connected, inRange) {
        var list = raw.map(function (d) {
            var p = paired.indexOf(d.mac) >= 0;
            var c = connected.indexOf(d.mac) >= 0;
            // connected implies in range; a device can't connect from out of range
            var ir = c || inRange.indexOf(d.mac) >= 0;
            return { mac: d.mac, name: d.name, paired: p, connected: c, inRange: ir };
        });
        list.sort(function (a, b) {
            var ra = a.paired ? (a.inRange ? 0 : 1) : 2;
            var rb = b.paired ? (b.inRange ? 0 : 1) : 2;
            if (ra !== rb) return ra - rb;
            var ca = a.connected ? 0 : 1, cb = b.connected ? 0 : 1;
            if (ca !== cb) return ca - cb;
            var na = (a.name || "").toLowerCase(), nb = (b.name || "").toLowerCase();
            return na < nb ? -1 : (na > nb ? 1 : 0);
        });
        return list;
    }
```

- [ ] **Step 3: Add the `parseInRange` helper**

Immediately after `parseDevices` (after line 56, the closing `}` of `parseDevices`), add:

```qml
    function parseInRange(text) {
        // bluetoothctl discovery (no tty → no ANSI) emits lines like
        // "[CHG] Device AA:BB:CC:DD:EE:FF RSSI: -72" for devices seen in
        // range. Collect the MAC from any line containing "RSSI:".
        // Plain string ops only — no regex (Qt V4 lookaround is unsafe).
        var out = [], ls = text.split('\n');
        for (var i = 0; i < ls.length; i++) {
            var l = ls[i];
            if (l.indexOf("RSSI:") < 0) continue;
            var di = l.indexOf("Device ");
            if (di < 0) continue;
            var rest = l.substring(di + 7);
            var sp = rest.indexOf(" ");
            var mac = sp < 0 ? rest : rest.substring(0, sp);
            if (out.indexOf(mac) < 0) out.push(mac);
        }
        return out;
    }
```

- [ ] **Step 4: Make `setPowered` optimistic**

Replace the existing `setPowered` (lines 60-71):

```qml
    function setPowered(on) {
        // On-demand daemon: start bluez then power the adapter; on the way
        // down power off then stop bluez so nothing runs (no battery cost).
        if (on)
            powerSet.command = ["sh", "-c",
                "systemctl start bluetooth && sleep 1 && timeout 5 bluetoothctl power on"];
        else
            powerSet.command = ["sh", "-c",
                "timeout 3 bluetoothctl power off; systemctl stop bluetooth"];
        powerSet.running = true;
        reprobe.restart();
    }
```

with:

```qml
    function setPowered(on) {
        // Optimistic: flip `powered` immediately so the switch and picker
        // react instantly instead of waiting for the 2.5 s reprobe. On the
        // way down also clear every device set so the list empties at once.
        // reprobe still runs and reconciles (e.g. reverts on polkit-denied
        // start). On-demand daemon: start bluez then power the adapter; on
        // the way down power off then stop bluez (no battery cost).
        root.powered = on;
        if (!on) {
            root._raw = [];
            root.pairedMacs = [];
            root.connectedMacs = [];
            root.inRangeMacs = [];
            root.activeDevice = "";
        }
        if (on)
            powerSet.command = ["sh", "-c",
                "systemctl start bluetooth && sleep 1 && timeout 5 bluetoothctl power on"];
        else
            powerSet.command = ["sh", "-c",
                "timeout 3 bluetoothctl power off; systemctl stop bluetooth"];
        powerSet.running = true;
        reprobe.restart();
    }
```

- [ ] **Step 5: Clear `inRangeMacs` in the probe's daemon-down branch**

In the `probe` StdioCollector's `onStreamFinished`, the `if (!root.available)` block (lines 106-112) clears the device sets. Add `inRangeMacs` to it. Replace:

```qml
                if (!root.available) {           // daemon/adapter down → clear, don't churn
                    root._raw = [];
                    root.pairedMacs = [];
                    root.connectedMacs = [];
                    root.activeDevice = "";
                    return;
                }
```

with:

```qml
                if (!root.available) {           // daemon/adapter down → clear, don't churn
                    root._raw = [];
                    root.pairedMacs = [];
                    root.connectedMacs = [];
                    root.inRangeMacs = [];
                    root.activeDevice = "";
                    return;
                }
```

- [ ] **Step 6: Capture RSSI from the scan stream**

Replace the `scanProc` block (lines 136-144):

```qml
    Process {
        id: scanProc
        command: ["sh", "-c", "timeout 6 bluetoothctl --timeout 5 scan on 2>/dev/null"]
        // devices only appear once discovery has run, so re-list on finish
        onRunningChanged: if (!running) {
            listProc.running = true;
            connGet.running = true;
        }
    }
```

with:

```qml
    Process {
        id: scanProc
        command: ["sh", "-c", "timeout 6 bluetoothctl --timeout 5 scan on 2>/dev/null"]
        // discovery stream carries RSSI for in-range devices; parse it to
        // learn which devices are reachable right now
        stdout: StdioCollector {
            onStreamFinished: root.inRangeMacs = root.parseInRange(text)
        }
        // devices only appear once discovery has run, so re-list on finish
        onRunningChanged: if (!running) {
            listProc.running = true;
            connGet.running = true;
        }
    }
```

- [ ] **Step 7: Verify the file loads**

Run: `qs -p quickshell/.config/quickshell/shell.qml --check 2>&1 | head -20`
Expected: no QML parse/type errors mentioning `BtCtl.qml`. (If `--check` is unavailable, rely on the live-reload instance reporting clean; per the project note, a fresh validation needs `pkill qs` + clearing the QML cache, but live-reload is sufficient here.)

- [ ] **Step 8: Commit**

```bash
git add quickshell/.config/quickshell/BtCtl.qml
git commit -m "BtCtl: in-range tracking, optimistic toggle, tiered device sort

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: BtRow — dim out-of-range paired rows + header re-scan glyph

**Files:**
- Modify: `quickshell/.config/quickshell/BtRow.qml`

- [ ] **Step 1: Give the status CcText an id**

The right-aligned status `CcText` (lines 37-50) is anonymous. Add `id: btStatus` so the re-scan glyph can anchor to it. Change its opening:

```qml
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
```

to:

```qml
    CcText {
        id: btStatus
        anchors.right: parent.right; anchors.rightMargin: 12
```

- [ ] **Step 2: Add the header re-scan glyph**

Immediately after the `btStatus` CcText block (after its closing `}` at line 50), add:

```qml
    // header re-scan trigger — bitmap-native glyph, only while powered &
    // expanded. Not part of the j/k list nav, so ControlCenter also binds
    // `r` for keyboard parity. If ↻ renders mushy on Terminess, swap text
    // to "scan".
    CcText {
        id: rescanBtn
        visible: root.expanded && BtCtl.powered
        anchors.right: btStatus.left; anchors.rightMargin: 10
        y: btLabel.y
        text: "↻"
        color: Theme.muted
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: BtCtl.scan()
        }
    }
```

- [ ] **Step 3: Dim out-of-range paired device names**

Replace the device-name `CcText` color (line 129):

```qml
                color: devItem.sel ? Theme.bg : (devItem.modelData.connected ? Theme.accentText : Theme.fg)
```

with:

```qml
                color: devItem.sel ? Theme.bg
                     : (devItem.modelData.connected ? Theme.accentText
                        : ((devItem.modelData.paired && !devItem.modelData.inRange)
                           ? Theme.muted : Theme.fg))
```

- [ ] **Step 4: Verify the file loads and check the glyph renders**

Run: `qs -p quickshell/.config/quickshell/shell.qml --check 2>&1 | head -20`
Expected: no errors mentioning `BtRow.qml`.
Then open the Control Center BT picker on the live instance and confirm the `↻` glyph is crisp (not blurry/boxed). If it renders mushy, change `text: "↻"` to `text: "scan"` in `rescanBtn` (per the bitmap-glyph preference) and re-check.

- [ ] **Step 5: Commit**

```bash
git add quickshell/.config/quickshell/BtRow.qml
git commit -m "BtRow: dim out-of-range paired devices, add header re-scan glyph

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: ControlCenter — `r` re-scans while BT picker open

**Files:**
- Modify: `quickshell/.config/quickshell/ControlCenter.qml`

- [ ] **Step 1: Add the `r` key branch**

In `panel`'s `Keys.onPressed` handler, after the Return/Enter/Space branch (the `else if` ending at line 353, before the closing `}` of the handler), add a new branch. The Cyrillic `к` sits at the physical `r` position in JCUKEN, matching the existing layout-independence pattern:

```qml
            } else if (t === "r" || t === "к") {
                // re-scan only meaningful in the BT picker (row 6) when powered
                if (listOpen && cc.openRow === 6 && BtCtl.powered) {
                    BtCtl.scan();
                    event.accepted = true;
                }
            }
```

- [ ] **Step 2: Verify the file loads**

Run: `qs -p quickshell/.config/quickshell/shell.qml --check 2>&1 | head -20`
Expected: no errors mentioning `ControlCenter.qml`.

- [ ] **Step 3: Commit**

```bash
git add quickshell/.config/quickshell/ControlCenter.qml
git commit -m "ControlCenter: r re-scans while BT picker open

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Manual end-to-end verification

**Files:** none (live-reload behavior check)

- [ ] **Step 1: Run through the spec's test matrix on the live instance**

With `qs` running (live-reload), open the Control Center BT picker and confirm:

- Toggle BT **off** → switch flips and picker collapses immediately (no ~2.5s lag).
- Toggle BT **on** → switch flips immediately; devices populate after the scan.
- A paired-but-powered-off device appears in tier 2, **dimmed**.
- Powering that device on, then re-scanning, moves it to tier 1 (undimmed).
- An unpaired discovered device appears last (tier 3) with the hollow unpaired mark.
- Header `↻` glyph and the `r` key both show `scanning…` and refresh the list.
- With the bluez daemon down, the picker still degrades to "off" (fail-fast probe intact).

- [ ] **Step 2: Confirm no regressions**

Verify connect (paired) and pair+connect (unpaired) and disconnect still work and collapse the picker as before.

---

## Notes for the executor

- Do **not** commit to `laniakea`. All work stays on `bt-picker-rework`; merge only after Task 4 passes (use the finishing-a-development-branch skill).
- `docs/` is gitignored in this repo, so the plan/spec files are local-only and never appear in `git add`.
- `Theme.muted`, `Theme.bg`, `Theme.accentText`, `Theme.fg` already exist and are used throughout `BtRow.qml` — no new theme keys.
