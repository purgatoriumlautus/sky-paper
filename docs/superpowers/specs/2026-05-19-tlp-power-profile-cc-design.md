# TLP tuning + Power-profile control in Quickshell CC

**Date:** 2026-05-19
**Machine:** ThinkPad X280 (Lenovo 20KES10600), Intel i5-8350U, Samsung MZVLB256HAHQ-000L7

## Goal

1. Apply a minimal, ThinkPad-specific TLP override (charge thresholds only) so the battery stops aging via constant 100% float-charge.
2. Replace the existing CC row-7 placeholder (`"Power — tlp pending"`) with a working 4-mode CPU EPP cycler, keyboard-driven like the rest of the panel.

These are independent enough to ship in two commits, but they're scoped together because the EPP defaults that TLP applies on plug/unplug events directly determine what state the CC cycler observes on `refresh()`.

## Part 1 — TLP config

### What we change

Drop-in file `/etc/tlp.d/00-aru.conf`:

```
START_CHARGE_THRESH_BAT0=85
STOP_CHARGE_THRESH_BAT0=90
```

That's it. EPP defaults stay at TLP's `balance_performance` (AC) / `balance_power` (BAT). No other overrides.

### Why a drop-in and not /etc/tlp.conf

- `/etc/tlp.d/*.conf` is loaded after `/etc/tlp.conf` and overrides anything in it.
- Pacman never produces `.pacnew` on it (it's our file, not the package's).
- Diff is tiny and reviewable: the dotfiles repo carries the two lines, nothing else.

### Why 85/90

Battery is SMP 01AV471 (48 Wh design), 64 cycles, already at 90.3% capacity — strongly suggests a lot of plugged-in time. 85/90 cuts the time spent at 100% SoC, which is the main aging vector for Li-ion at room temp. We keep ~39 Wh of usable capacity (vs ~43 Wh today), trading <10% capacity headroom for substantially slower future degradation.

### Why no EPP overrides

User accepted TLP defaults: `balance_performance` on AC, `balance_power` on BAT. Both are in the 4-mode CC set below, so a plug/unplug event always lands the cycler on a known label — no rounding needed.

### Extras

- `pacman -S smartmontools` — enables SMART block in `tlp-stat -d`. Do **not** enable `smartd.service`; pacman install is enough.
- `ethtool` declined.

### Dotfiles layout

New top-level package directory `tlp/` containing:

```
tlp/etc/tlp.d/00-aru.conf
tlp/install.sh
```

`install.sh` mirrors `keyd/install.sh` style: `sudo install -m 0644 ...` for the conf, `sudo pacman -S --needed tlp tlp-rdw smartmontools`, then `sudo systemctl enable --now tlp.service` (idempotent — it's already enabled), and `sudo tlp start` to apply immediately.

### Verification

After install:
- `cat /sys/class/power_supply/BAT0/charge_control_start_threshold` → `85`
- `cat /sys/class/power_supply/BAT0/charge_control_end_threshold` → `90`
- `sudo tlp-stat -b | grep -E 'charge_control'` confirms.

## Part 2 — CC row 7: EPP cycler

### UX

Single row, same height/highlight as the other CC rows. Label `"Power"` on the left, current EPP label on the right in `Theme.accentText`. Four modes cycle on `H`/`L`/`Enter`:

| Index | EPP value           | Right-side label    |
|-------|---------------------|---------------------|
| 0     | `performance`       | `Performance`       |
| 1     | `balance_performance` | `Balanced (perf)` |
| 2     | `balance_power`     | `Balanced (save)`   |
| 3     | `power`             | `Power Save`        |

`H` cycles -1, `L` and `Enter` cycle +1, both modulo 4. No list-mode expansion — 4 items don't justify the extra UI state. Mouse click cycles +1 (matches `Enter`).

### Components

**`quickshell/.config/quickshell/Power.qml`** — new `pragma Singleton`. Same shape as `Brightness.qml`:

- Property `mode: int` (0–3 index into the EPP table). This is what `PowerRow` binds to — the right-side label flips instantly on every cycle.
- `refresh()`: reads `/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference` via a `Process { command: ["cat", ...] }`, maps the string to an index. `default` → 1 (Balanced perf). Anything unrecognized → 1, logged once.
- `cycle(dir)`: `mode = (mode + dir + 4) % 4`, then `applyTimer.restart()`. The actual `/sys` write is deferred — see below.
- `applyTimer`: `Timer { interval: 1500; repeat: false; onTriggered: { /* pkexec set-epp <table[mode]> */ } }`. Every `cycle()` call restarts it. Net effect: after the user stops pressing keys for 1.5 s, exactly one `pkexec` fires with the final mode. Mashing `L L L` from Performance → Power Save issues one write, not three.
- Apply: `Process { command: ["pkexec", "/usr/local/bin/set-epp", <epp>] }`. Optimistic — `mode` was already updated when the user pressed the key. If the process exits non-zero, log and re-`refresh()` to resync from `/sys`.
- Edge case: if the popup closes before the timer fires, we still want the pending write to land. Don't bind the timer to popup visibility; the singleton outlives `cc`. The opportunity cost of a stray write is zero.

**`quickshell/.config/quickshell/PowerRow.qml`** — new row, modeled on `CcStatusRow` but with `MouseArea.onClicked` calling `Power.cycle(1)` and matching the focus highlight pattern.

**`quickshell/.config/quickshell/ControlCenter.qml`** — wiring:

- Replace the `CcStatusRow { ... label: "Power"; status: "tlp pending" ... }` block at row 7 with `PowerRow { cc: cc; rowIndex: 7 }`.
- `dispatchHL`: replace the row-7 no-op with `case 7: Power.cycle(dir); break;`.
- `handleEnter`: add `case 7: Power.cycle(1); break;`.
- `refresh()`: add `Power.refresh();` so the row reflects reality each time the panel opens.

**`quickshell/.config/quickshell/epp-toggle.rules`** — new polkit rule, sibling of `bluetooth-toggle.rules`. Identical structure:

```js
polkit.addRule(function (action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/bin/set-epp" &&
        subject.user == "aru") {
        return polkit.Result.YES;
    }
});
```

**`quickshell/.config/quickshell/set-epp`** — new helper, installed to `/usr/local/bin/set-epp`. ~10 lines:

```sh
#!/bin/sh
set -eu
v=$1
case "$v" in
    performance|balance_performance|balance_power|power|default) ;;
    *) printf 'unknown EPP value: %s\n' "$v" >&2; exit 1 ;;
esac
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    printf '%s\n' "$v" > "$f"
done
```

Whitelist is hard-coded; no shell-expanded user input reaches anything sensitive. Writes to every CPU because `intel_pstate` doesn't propagate per-cpu writes on this kernel.

### Install

`quickshell/install.sh` already exists for the polkit rule. Add to it:

- `sudo install -m 0755 quickshell/.config/quickshell/set-epp /usr/local/bin/set-epp`
- `sudo install -m 0644 quickshell/.config/quickshell/epp-toggle.rules /etc/polkit-1/rules.d/49-epp-toggle.rules`

Polkit picks up `rules.d/` changes live, no daemon restart.

### Behaviour on plug/unplug

TLP rewrites EPP on every power-source transition. Our `refresh()` runs on every CC open, so the displayed label is always current. Between transitions, our writes stick. This is the live-only semantic the user asked for — no `tlp.conf` rewriting, no persistence across plug events. If the user wants a different default after plug, that's a TLP config change, not a CC one.

### Failure modes

- `pkexec` denied (rule not installed): the row label desyncs from `/sys` for one refresh cycle, then snaps back on next CC open. Log to stderr.
- `set-epp` helper missing: `pkexec` fails fast, same recovery.
- EPP file disappears (kernel changed driver): `refresh()` lands on index 1, cycler still operates but writes silently fail. Acceptable — out-of-scope edge case.

### Out of scope

- Battery-charge-threshold UI in CC (would be a slider, separate row).
- `tlp ac` / `tlp bat` / `tlp start` profile-forcing.
- Platform profile (X280 doesn't expose `/sys/firmware/acpi/platform_profile`).
- TLP enable/disable toggle.
- Reading EPP via polling — refresh on CC open is enough.

## Implementation order

1. **TLP first.** Land `tlp/etc/tlp.d/00-aru.conf` + `tlp/install.sh`, run install, verify thresholds, install smartmontools. Commit.
2. **CC second.** Land `set-epp` helper + polkit rule, `Power.qml`, `PowerRow.qml`, wire into `ControlCenter.qml`, update `quickshell/install.sh`. Commit.

Two commits, each independently testable and revertable.
