# TLP tuning + CC EPP cycler — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `/etc/tlp.d/` drop-in setting BAT0 charge thresholds to 85/90, then replace the row-7 placeholder in the Quickshell control center with a 4-mode EPP cycler (Performance / Balanced perf / Balanced save / Power Save), 1.5 s debounced, applied via a pkexec'd helper guarded by a scoped polkit rule.

**Architecture:** New `tlp/` dotfiles package follows the existing `keyd/` / `sysctl/` / `sshd/` / `nftables/` convention (root-owned `/etc/`, `install.sh` as source of truth, not stow). New Quickshell pieces follow the existing `Brightness` / `Radio` / `bluetooth-toggle.rules` patterns: a `pragma Singleton` for state + a row component for UI + a polkit rule + a small POSIX-sh helper. The CC `cycle()` updates the visible label immediately and restarts a 1500 ms Timer; only when the user stops cycling does one `pkexec /usr/local/bin/set-epp` fire.

**Tech Stack:** Bash install scripts · TLP 1.10 drop-ins · QML6 (Quickshell) · polkit JS rules · pkexec · POSIX sh helper.

**Spec:** `docs/superpowers/specs/2026-05-19-tlp-power-profile-cc-design.md`

---

## File Structure

**New files:**

- `tlp/etc/tlp.d/00-aru.conf` — two-line drop-in, only the deltas vs TLP defaults.
- `tlp/install.sh` — installs the drop-in, ensures `tlp`/`tlp-rdw`/`smartmontools` present, runs `tlp start`.
- `quickshell/.config/quickshell/set-epp` — POSIX-sh helper, will be installed to `/usr/local/bin/set-epp`. Whitelists the EPP token, writes to every CPU.
- `quickshell/.config/quickshell/epp-toggle.rules` — polkit rule, will be installed to `/etc/polkit-1/rules.d/49-epp-toggle.rules`. Sibling of `bluetooth-toggle.rules`, install instructions in header comment.
- `quickshell/.config/quickshell/Power.qml` — `pragma Singleton`. Holds `mode: int` (0-3), reads `/sys/.../energy_performance_preference` on `refresh()`, exposes `cycle(dir)` which updates `mode` immediately and restarts a 1500 ms `applyTimer` whose `onTriggered` does the `pkexec` write.
- `quickshell/.config/quickshell/PowerRow.qml` — visual row, modeled on `CcStatusRow`. Renders `"Power"` left + label right (in `Theme.accentText`), focus highlight, mouse click cycles `+1`.

**Modified files:**

- `quickshell/.config/quickshell/ControlCenter.qml` — replace the row-7 `CcStatusRow` placeholder with `PowerRow`, add row-7 cases to `dispatchHL` and `handleEnter`, add `Power.refresh()` to `refresh()`.

---

## Task 1: TLP drop-in + install script

**Files:**
- Create: `tlp/etc/tlp.d/00-aru.conf`
- Create: `tlp/install.sh`

- [ ] **Step 1: Create the TLP drop-in**

Create `tlp/etc/tlp.d/00-aru.conf` with exactly:

```
# laniakea (ThinkPad X280) — TLP overrides.
# Drop-in for /etc/tlp.d/, loaded after /etc/tlp.conf and overrides it.
# Keep this file minimal: only deltas vs TLP defaults.
#
# ThinkPad-native charge thresholds via natacpi (thinkpad_acpi). 85/90 is
# the "mild protection" pair — keeps ~39 Wh of the 43 Wh full capacity
# usable while avoiding the 100 % float-charge that's been visibly aging
# this pack (90.3 % capacity at only 64 cycles).
START_CHARGE_THRESH_BAT0=85
STOP_CHARGE_THRESH_BAT0=90
```

- [ ] **Step 2: Create the install script**

Create `tlp/install.sh` with mode 0755:

```bash
#!/usr/bin/env bash
# Install TLP overrides for laniakea. Run with sudo.
#
# Why a script and not stow: /etc/tlp.d/ is root-owned and outside $HOME.
# Same pattern as keyd/install.sh, sysctl/install.sh, nftables/install.sh.
#
# What it does:
#   - Ensures tlp, tlp-rdw, smartmontools are installed.
#   - Drops 00-aru.conf into /etc/tlp.d/.
#   - Enables tlp.service (idempotent) and runs `tlp start` to apply now.
#
# Revert just the thresholds: rm /etc/tlp.d/00-aru.conf && tlp start
# (TLP itself was already enabled before this script; leave it alone.)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pacman -S --needed tlp tlp-rdw smartmontools

install -d -m 755 /etc/tlp.d
install -m 644 "$SRC/etc/tlp.d/00-aru.conf" /etc/tlp.d/00-aru.conf

systemctl enable --now tlp.service
# Re-read /etc/tlp.d/ — enable --now is a no-op when service is already
# running, so re-runs after editing the conf won't pick up changes
# without this.
tlp start

echo "Installed. Spot-check:"
echo "  cat /sys/class/power_supply/BAT0/charge_control_start_threshold  # → 85"
echo "  cat /sys/class/power_supply/BAT0/charge_control_end_threshold    # → 90"
```

- [ ] **Step 3: Make it executable**

```bash
chmod +x tlp/install.sh
```

- [ ] **Step 4: Verify file contents**

```bash
cat tlp/etc/tlp.d/00-aru.conf
head -5 tlp/install.sh
ls -l tlp/install.sh
```

Expected: drop-in shows the two threshold lines (plus comments); install.sh starts with the shebang; install.sh has `x` bit set.

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add tlp/
git commit -m "tlp: drop-in for 85/90 BAT0 charge thresholds

ThinkPad X280 (laniakea). /etc/tlp.d/00-aru.conf is loaded after
/etc/tlp.conf and overrides only the two values we change — EPP
defaults stay at TLP defaults. install.sh follows the keyd/sysctl/
nftables pattern: not stow, root-owned target, idempotent."
```

---

## Task 2: Run TLP install and verify

**Files:** none modified — verification only.

- [ ] **Step 1: Run the installer**

```bash
sudo /home/aru/dotfiles/tlp/install.sh
```

Expected: pacman either says "nothing to do" or installs smartmontools (already-present tlp + tlp-rdw are no-ops). Final lines print the spot-check commands.

- [ ] **Step 2: Verify thresholds via /sys**

```bash
cat /sys/class/power_supply/BAT0/charge_control_start_threshold
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

Expected: `85` then `90`.

- [ ] **Step 3: Confirm TLP sees the new config**

```bash
sudo tlp-stat -b | grep -E 'charge_control|START_CHARGE|STOP_CHARGE' | head -10
```

Expected: at least one line showing `START_CHARGE_THRESH_BAT0="85"` (from our drop-in) and `STOP_CHARGE_THRESH_BAT0="90"`, plus the `/sys` `charge_control_*_threshold = 85` / `= 90` lines.

- [ ] **Step 4: No commit — this task only verifies real-system state**

If the spot-check fails, fix Task 1 first, re-run install, re-verify. Do not proceed to Task 3 unless `/sys` shows 85/90.

---

## Task 3: `set-epp` helper script

**Files:**
- Create: `quickshell/.config/quickshell/set-epp`

- [ ] **Step 1: Create the helper**

Create `quickshell/.config/quickshell/set-epp` with mode 0755:

```sh
#!/bin/sh
# Set CPU energy_performance_preference for all cores. Called via pkexec
# from Quickshell's Power.qml — the polkit rule (epp-toggle.rules) allows
# user `aru` to pkexec this path without a password prompt.
#
# Argv: one of the allowed EPP tokens. Anything else exits 1.
#
# Install once (needs root):
#   sudo install -m 0755 ~/.config/quickshell/set-epp /usr/local/bin/set-epp
set -eu
v=${1:-}
case "$v" in
    performance|balance_performance|balance_power|power|default) ;;
    *) printf 'set-epp: unknown EPP value: %s\n' "$v" >&2; exit 1 ;;
esac
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    printf '%s\n' "$v" > "$f"
done
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x quickshell/.config/quickshell/set-epp
```

- [ ] **Step 3: Smoke-test directly (still needs sudo at this point — polkit rule not installed yet)**

```bash
sudo quickshell/.config/quickshell/set-epp balance_performance
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
cat /sys/devices/system/cpu/cpu7/cpufreq/energy_performance_preference
```

Expected: both print `balance_performance`.

- [ ] **Step 4: Reject-test the whitelist**

```bash
sudo quickshell/.config/quickshell/set-epp evil; echo "exit=$?"
```

Expected: stderr `set-epp: unknown EPP value: evil`, exit code `1`. `/sys` value unchanged.

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/set-epp
git commit -m "quickshell: add set-epp helper

POSIX-sh helper that writes one whitelisted EPP token to every CPU's
energy_performance_preference. Will be invoked via pkexec from
Power.qml; polkit rule (next commit) allows user aru to run it
without a password."
```

---

## Task 4: polkit rule + install both, verify password-less pkexec

**Files:**
- Create: `quickshell/.config/quickshell/epp-toggle.rules`

- [ ] **Step 1: Create the polkit rule**

Create `quickshell/.config/quickshell/epp-toggle.rules`:

```js
// Lets the Power row in quickshell change CPU EPP without a password
// prompt — Power.qml shells out to `pkexec /usr/local/bin/set-epp <v>`
// every time the user cycles the row.
//
// Least-privilege: ONLY the exact /usr/local/bin/set-epp path, ONLY
// user `aru`. Everything else still goes through normal polkit auth.
//
// Install once (needs root):
//   sudo install -m 0644 ~/.config/quickshell/epp-toggle.rules \
//        /etc/polkit-1/rules.d/49-epp-toggle.rules
// No daemon restart needed; polkit picks up rules.d changes live.

polkit.addRule(function (action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/bin/set-epp" &&
        subject.user == "aru") {
        return polkit.Result.YES;
    }
});
```

- [ ] **Step 2: Install both system-side files**

```bash
sudo install -m 0755 /home/aru/dotfiles/quickshell/.config/quickshell/set-epp /usr/local/bin/set-epp
sudo install -m 0644 /home/aru/dotfiles/quickshell/.config/quickshell/epp-toggle.rules /etc/polkit-1/rules.d/49-epp-toggle.rules
```

- [ ] **Step 3: Verify password-less pkexec works**

```bash
pkexec /usr/local/bin/set-epp performance
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

Expected: no password prompt. `/sys` shows `performance`.

- [ ] **Step 4: Restore a sensible baseline before continuing**

```bash
pkexec /usr/local/bin/set-epp balance_performance
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

Expected: `balance_performance`. (TLP will overwrite this on the next plug event anyway — doesn't matter, just don't leave the box pinned at `performance`.)

- [ ] **Step 5: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/epp-toggle.rules
git commit -m "quickshell: polkit rule for set-epp

Scoped to action org.freedesktop.policykit.exec, program
/usr/local/bin/set-epp, subject aru. Sibling of
bluetooth-toggle.rules, same install pattern (header comment).
With this in place pkexec /usr/local/bin/set-epp runs without
prompting."
```

---

## Task 5: `Power.qml` singleton

**Files:**
- Create: `quickshell/.config/quickshell/Power.qml`

- [ ] **Step 1: Create the singleton**

Create `quickshell/.config/quickshell/Power.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU energy_performance_preference cycler. 4 modes, debounced.
//
// PowerRow binds to `mode` (the visible label flips instantly on every
// cycle). The actual /sys write is deferred 1500 ms via applyTimer so
// mashing L L L from Performance to Power Save issues one pkexec, not
// three. The write is done by /usr/local/bin/set-epp via pkexec — see
// epp-toggle.rules for the polkit pass-through.
Singleton {
    id: root

    // 0=Performance, 1=Balanced (perf), 2=Balanced (save), 3=Power Save
    property int mode: 1

    readonly property var eppValues: [
        "performance",
        "balance_performance",
        "balance_power",
        "power"
    ]
    readonly property var labels: [
        "Performance",
        "Balanced (perf)",
        "Balanced (save)",
        "Power Save"
    ]

    function refresh() { getProc.running = true; }

    function cycle(dir) {
        root.mode = (root.mode + dir + 4) % 4;
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 1500
        repeat: false
        onTriggered: {
            setProc.command = ["pkexec", "/usr/local/bin/set-epp", root.eppValues[root.mode]];
            setProc.running = true;
        }
    }

    Process {
        id: getProc
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim();
                var idx = root.eppValues.indexOf(v);
                // unknown / "default" → Balanced (perf)
                root.mode = idx >= 0 ? idx : 1;
            }
        }
    }
    Process {
        id: setProc
        onExited: (exitCode) => {
            // pkexec denied / set-epp missing / etc. Resync the label
            // from /sys so the row doesn't lie.
            if (exitCode !== 0) root.refresh();
        }
    }
}
```

- [ ] **Step 2: Live-reload Quickshell and check the QML loads cleanly**

In another terminal (kill+restart will lose stale-cache errors per memory — `qs` running already live-reloads on save):

```bash
journalctl --user -t quickshell --since '1 min ago' | tail -30
```

Expected: no QML parse errors for `Power.qml`. (If you see errors, they're likely typos in the file you just wrote — fix and the next save reloads automatically.)

- [ ] **Step 3: Parse-check only (lazy singleton — no runtime test possible yet)**

`pragma Singleton` in Quickshell is lazily instantiated — until something references `Power.*` (which only happens in Task 7), the singleton is never loaded and a `Component.onCompleted` would never fire. So a runtime sanity-poke isn't possible at this step.

Instead, just confirm the file parses cleanly. If `qs` is running, saving Power.qml triggers a parse pass even without instantiation. Check:

```bash
journalctl --user -t quickshell --since '30 sec ago' | grep -iE 'Power\.qml|error|warning' | head
```

Expected: no errors/warnings naming `Power.qml`. If you see "Singleton not found" or similar, that's fine — it just means nothing imports it yet (Task 7 fixes that). Runtime behaviour gets tested in Task 7.

- [ ] **Step 4: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/Power.qml
git commit -m "quickshell: Power singleton (EPP cycler, 1500ms debounced)

pragma Singleton holding 4-mode index (0=Performance .. 3=Power Save)
mapped to the EPP tokens performance / balance_performance /
balance_power / power. cycle(dir) updates the visible mode instantly
and restarts a 1500ms Timer; only on Timer expiry does one pkexec
/usr/local/bin/set-epp fire. On non-zero exit, refresh() resyncs the
label from /sys so the row never lies."
```

---

## Task 6: `PowerRow.qml`

**Files:**
- Create: `quickshell/.config/quickshell/PowerRow.qml`

- [ ] **Step 1: Create the row component**

Create `quickshell/.config/quickshell/PowerRow.qml`:

```qml
import QtQuick
import Quickshell

// CC row 7: Power profile (EPP cycler).
// Label left, current mode label right (in accent). H/L/Enter cycle in
// ControlCenter.qml; mouse click here cycles +1.
Item {
    id: row
    property var cc
    property int rowIndex: 0

    width: cc ? cc.width : 0
    height: 32

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === row.rowIndex) ? Theme.accentSoft : "transparent"
    }
    CcText {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "Power"
    }
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Power.labels[Power.mode]
        color: Theme.accentText
        elide: Text.ElideRight
        width: 180
        horizontalAlignment: Text.AlignRight
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { row.cc.focusedRow = row.rowIndex; Power.cycle(1); }
    }
}
```

- [ ] **Step 2: Verify the row file loads (Quickshell will only try to instantiate it once we wire it in Task 7, but a save still triggers a recompile pass)**

```bash
journalctl --user -t quickshell --since '30 sec ago' | tail -20
```

Expected: no parse errors mentioning `PowerRow.qml`. (Instantiation errors won't show until Task 7.)

- [ ] **Step 3: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/PowerRow.qml
git commit -m "quickshell: PowerRow row component

Modeled on CcStatusRow: label left, status (current EPP label) right
in accent, focus highlight on cc.focusedRow match. Mouse click
cycles +1. Will be wired into ControlCenter row 7 next commit."
```

---

## Task 7: Wire row 7 in ControlCenter, smoke-test, commit

**Files:**
- Modify: `quickshell/.config/quickshell/ControlCenter.qml`

- [ ] **Step 1: Replace the row-7 placeholder**

In `quickshell/.config/quickshell/ControlCenter.qml`, find this block (currently around lines 326-329):

```qml
            // 7 — Power profile (TLP placeholder)
            CcStatusRow {
                cc: cc; rowIndex: 7; label: "Power"
                status: "tlp pending"; active: false
            }
```

Replace it with:

```qml
            // 7 — Power profile (EPP cycler — see Power.qml)
            PowerRow { cc: cc; rowIndex: 7 }
```

- [ ] **Step 2: Add row-7 case to `dispatchHL`**

In the same file, find the `dispatchHL` function (currently around lines 145-157). The row-7 line currently reads:

```qml
            case 7: /* Power profile — placeholder */ break;
```

Replace it with:

```qml
            case 7: Power.cycle(dir); break;
```

- [ ] **Step 3: Add row-7 case to `handleEnter`**

In the same file, find the `handleEnter` function (currently around lines 158-168). It has no row-7 case. Add one (before `case 8`):

```qml
            case 7: Power.cycle(1); break;
```

So the function ends up looking like:

```qml
    function handleEnter() {
        switch (cc.focusedRow) {
            case 1: cc.toggleMute(); break;
            case 2: Radio.toggleAirplane(); break;
            case 3: NightLight.toggle(); break;
            case 4: cc.openList(); break;
            case 5: cc.openList(); break;
            case 6: cc.openList(); break;
            case 7: Power.cycle(1); break;
            case 8: cc.runPower(cc.footerCol); break;
        }
    }
```

- [ ] **Step 4: Add `Power.refresh()` to the panel-level `refresh()`**

In the same file, find the `refresh()` function (currently around lines 53-59):

```qml
    function refresh() {
        Brightness.refresh();
        NightLight.refresh();
        Radio.refresh();
        WifiCtl.refreshActive();
        BtCtl.refreshActive();
    }
```

Add `Power.refresh();` to it:

```qml
    function refresh() {
        Brightness.refresh();
        NightLight.refresh();
        Radio.refresh();
        Power.refresh();
        WifiCtl.refreshActive();
        BtCtl.refreshActive();
    }
```

- [ ] **Step 5: Smoke test — open CC, verify the row appears with a real label**

Open the Control Center via whatever shortcut you normally use, or:

```bash
journalctl --user -t quickshell --since '20 sec ago' | tail -30
```

Visually: row 7 should show `Power` on the left and the current EPP label on the right (probably `Balanced (perf)`). No `tlp pending` placeholder.

Expected: no QML errors in the journal.

- [ ] **Step 6: Smoke test — cycle the row**

With CC open, focus row 7 (J/K until it's highlighted), then:

- Press `L` once → label changes to next mode immediately. `/sys` does **not** change yet.
- Press `L` two more times → label cycles, still no `/sys` change.
- Wait ~1.5 s → `pkexec` fires, `/sys` should now match the displayed label.

Verify from another terminal:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
```

Expected: the EPP token matches whatever the visible label says (e.g., label `Power Save` → `/sys` says `power`).

- [ ] **Step 7: Smoke test — reopen converges**

Close CC (`Esc`), reopen. Row 7 label should match `/sys` immediately on open (this is the `Power.refresh()` you added in Step 4).

If you've just unplugged or plugged AC, TLP will have rewritten `/sys` to its default for the new power source. The label on next CC open should reflect that.

- [ ] **Step 8: Commit**

```bash
cd /home/aru/dotfiles
git add quickshell/.config/quickshell/ControlCenter.qml
git commit -m "quickshell/cc: wire row 7 to Power singleton + PowerRow

Replaces the 'tlp pending' CcStatusRow placeholder with PowerRow.
H/L/Enter dispatch to Power.cycle(); panel-level refresh() now
includes Power.refresh() so the label reflects /sys every time the
popup opens (incl. after a plug-event where TLP has reset EPP)."
```

---

## Self-Review

**Spec coverage:**

- TLP drop-in (`/etc/tlp.d/00-aru.conf`, 85/90, no EPP overrides) → Task 1.
- TLP install + verification → Task 2.
- `set-epp` helper with whitelist → Task 3.
- polkit rule for password-less pkexec → Task 4.
- `Power.qml` singleton with 4-mode index, refresh, debounce, write, error resync → Task 5.
- `PowerRow.qml` UI → Task 6.
- ControlCenter wiring (`PowerRow`, dispatchHL, handleEnter, refresh) → Task 7.
- Install of `set-epp` to `/usr/local/bin/` and polkit rule to `/etc/polkit-1/rules.d/` → Task 4 step 2 (manual `sudo install` lines, mirrors `bluetooth-toggle.rules` convention).
- Behaviour on plug/unplug (refresh on CC open) → Task 7 step 4 + step 7.
- smartmontools install → Task 1 step 2 (`pacman -S --needed`).

No spec gaps.

**Placeholder scan:** No `TBD` / `TODO` / "add appropriate" / "similar to" / "fill in" tokens. Every code block is concrete and complete.

**Type/name consistency:**

- `Power.mode` (int), `Power.labels` (array), `Power.eppValues` (array), `Power.cycle(dir)`, `Power.refresh()` — referenced consistently in Tasks 5, 6, 7.
- `cc`, `rowIndex` props on `PowerRow` match `BtRow`/`WifiRow`/`OutputRow` (verified against existing CC source).
- `Theme.accentText`, `Theme.accentSoft` — both already used by existing rows (`CcStatusRow`, `CcToggleRow`); names match.
- `/usr/local/bin/set-epp` path is identical in Task 3 header, Task 4 install command, Task 4 polkit rule, and Task 5 Power.qml command.
