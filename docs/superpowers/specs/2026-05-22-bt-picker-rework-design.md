# Bluetooth picker rework — design

**Date:** 2026-05-22
**Scope:** `quickshell/.config/quickshell/BtCtl.qml`, `BtRow.qml`, `ControlCenter.qml`

## Problem

The Control Center Bluetooth picker has four issues:

1. **Laggy turn-off.** `setPowered(off)` only flips `powered` after the 2.5s
   `reprobe`, so the toggle and picker look stuck "on" for ~2.5s after a click.
2. **No trusted/available distinction.** `devices` is the flat, unsorted `_raw`
   list tagged with `paired`/`connected`; paired devices are not grouped or
   ordered ahead of discovered ones.
3. **No manual re-scan.** A scan only fires automatically when the picker opens.
4. **No paired-available vs paired-unavailable split.** Whether a paired device
   is currently in range is not tracked at all.

## Design

### 1. Instant toggle (fixes laggy off / "close immediately")

`BtCtl.setPowered(on)` optimistically updates state *before* spawning the
process:

- Always set `root.powered = on` immediately.
- On `off`, immediately clear `_raw`, `pairedMacs`, `connectedMacs`,
  `activeDevice`, and the new `inRangeMacs`.

The existing 2.5s `reprobe` still runs and reconciles — e.g. if a polkit-denied
`systemctl start` fails on the `on` path, the probe reverts `powered` to false.
Net effect: the switch flips and the picker collapses the instant the user
clicks, instead of appearing stuck for ~2.5s. The `commitList` toggle-off path
already calls `closeList()`; with optimistic state the collapse is now visually
immediate.

### 2. In-range detection via RSSI

`scanProc` currently discards its stdout. Attach a `StdioCollector` and parse
the discovery stream for lines carrying `RSSI:` — bluetoothctl emits
`[CHG] Device <mac> RSSI: -72` (and `[NEW] …`) for devices seen during
discovery. Collect those MACs into a new property:

```
property var inRangeMacs: []   // MACs that reported RSSI in the latest scan
```

Parsing uses plain string ops only (find `"Device "`, take the MAC token, check
the line contains `"RSSI:"`) — no regex, per the Qt V4 lookaround constraint.
Connected devices are treated as in-range implicitly (a device cannot be
connected without being in range). `inRangeMacs` is cleared when the adapter
powers off (see §1) and repopulated by each scan.

### 3. Tiered ordering

`BtCtl.devices` (the computed property consumed by the UI) gains an `inRange`
field and is sorted into three tiers, connected-first then by name within each
tier:

1. paired **and** in-range
2. paired **and** out-of-range
3. unpaired (discovered)

```
inRange: connectedMacs.indexOf(mac) >= 0 || inRangeMacs.indexOf(mac) >= 0
```

Tier rank = `paired ? (inRange ? 0 : 1) : 2`. Sort key: `(tierRank, connected ?
0 : 1, name.toLowerCase())`.

### 4. Rendering (BtRow)

- **Out-of-range paired rows** render dimmed: name in `Theme.muted`, hollow pip.
  This makes the available/unavailable split read at a glance without a separate
  header or separator row.
- Connection pip (filled = connected, hollow = not) and the unpaired
  hollow-square mark stay as-is.
- **Header re-scan glyph:** on the expanded header's right side, a clickable
  bitmap-native glyph sits left of the status text. Use `↻`; if it renders mushy
  on Terminess, fall back to the literal text `scan` (per the bitmap-glyph
  preference — Terminus letters/box/blocks only, no fancy Nerd/Unicode icons).
  Clicking it calls `BtCtl.scan()`.
- **Keyboard parity:** bind `r` while the picker is open (in ControlCenter key
  handling) to call `BtCtl.scan()`, since the header glyph is not part of the
  j/k list navigation.
- Opening the picker still auto-scans once (`openList → BtCtl.scan()`,
  unchanged).

### 5. Untouched

Power-toggle row 0, the connect/pair/trust/disconnect flow, the polkit /
on-demand-daemon model (`systemctl start/stop bluetooth` + `bluetoothctl power
on/off`), and the fail-fast `probe` liveness gate all stay as they are.

## Files changed

- `BtCtl.qml` — `inRangeMacs` property; optimistic `setPowered`; `scanProc`
  stdout parsing; `devices` map gains `inRange` + tiered sort.
- `BtRow.qml` — dim out-of-range paired rows; header re-scan glyph.
- `ControlCenter.qml` — `r` key → `BtCtl.scan()` while BT picker open.

## Testing

Manual (Quickshell has no unit harness for this UI; live-reload):

- Toggle BT off → switch flips and picker collapses immediately (no ~2.5s lag).
- Toggle BT on → switch flips immediately; devices populate after scan.
- Open picker with a paired-but-off device → it appears in tier 2, dimmed.
- Power on the paired device → after a scan it moves to tier 1, undimmed.
- Discovered unpaired device appears in tier 3 with the unpaired mark.
- Click header glyph / press `r` → `scanning…` shows, list refreshes.
- bluez daemon down → picker still degrades to "off" (fail-fast probe intact).
