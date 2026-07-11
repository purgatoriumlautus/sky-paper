# Notifications — mako + Sky Paper + CC "Quiet" row

Status: approved spec, ready for implementation plan.
Branch target: a new feature branch off `laniakea` (per [[feedback-no-commits-no-branch-changes]]).
Resolves: todos.txt #2.

## Goal

Wire a notification daemon into the niri/Quickshell stack so `notify-send hi` actually
renders something, theme it pixel-aligned with the existing bar / CC / lock visuals, and
expose a Do-Not-Disturb toggle as a new ControlCenter row.

## Daemon: mako

Picked over swaync/dunst/fnott because:
- minimal ini config, no GTK dep (avoids leaking into unstarted GTK theme task #15)
- single CLI (`makoctl`) wraps cleanly into a Quickshell singleton, same shape as
  `Radio.qml` / `SuspendInhibit.qml` (Process + rfkill/systemd-inhibit pattern)
- the absence of a built-in notification center is a non-issue: CC owns control UX
- swaync's popup center would duplicate CC surface and drag in GTK theming

## Layout & alignment

Popups anchor **top-left**, opposite corner from CC (which drops top-right). Each popup
is visually one CC row pulled out of the panel: cream-tinted `barBg` @ 75%, 1px
`borderDim` hairline, Terminess Nerd Font Mono 16px, square corners, no icons.

Pixel-exact alignment with a niri window's top-left outer-border corner requires an
**asymmetric margin** because mako anchors to the post-exclusive-zone usable area:

- horizontal: 9 from screen-left → matches bar-left and a niri window's outer-border-left
  (niri `gaps 8` + `border width 1` = 9)
- vertical: 8 from usable-area top → matches the 8px clear gap niri leaves between the
  bar's exclusive zone and the window's outer-border-top

Result: `margin=8,9,8,9` (top right bottom left). The popup's top-left pixel sits
exactly where a niri window's border-outer top-left corner would be.

## Stack diagram

```
screen edge ─────────────────────────────────────
            │ bar (top exclusive, y=0..21)        │
            ├─ 9 ─── usable area ───────── 9 ──┤
            │ 8                                    │
            │ ┌──────────── mako popup ───────┐   │
            │ │  <b>Summary</b>  muted body   │ 32│
            │ └───────────────────────────────┘   │
            │   …more popups stack below…         │
            │                                      │
            │ ┌──────────── niri window ──────┐ ←border at the same x/y origin
            │ │                                │
```

## File layout

### New

- `mako/.config/mako/config` — new stow package, ini, ~30 lines
- `quickshell/.config/quickshell/Notifications.qml` — singleton wrapping `makoctl mode`

### Modified

- `quickshell/.config/quickshell/ControlCenter.qml` — insert "Quiet" row between
  Auto-suspend (4) and BT; shift downstream indices by 1
- `niri/.config/niri/config.kdl` — `spawn-at-startup "mako"`
- `CONTEXT.md` — drop "swaync not configured"; add mako row to Stack table; add
  `Notifications` to singleton list; document row index shift in CC
- `todos.txt` — mark #2 done

## mako config

```ini
# ~/.config/mako/config
font=Terminess Nerd Font Mono 16
background-color=#BFE4DED0   # Theme.barBg
text-color=#1F1812           # Theme.fg
border-color=#C5BFB5         # Theme.borderDim
border-size=1
border-radius=0
padding=6,12                 # 12px left inset matches CC row text inset
margin=8,9,8,9               # top right bottom left — aligns with niri window corner
width=300                    # CC implicitWidth
height=32                    # caps single-row height; body ellipsizes
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
border-color=#7A716A         # Theme.muted
default-timeout=3000

[urgency=high]
border-color=#9C5450         # Theme.warn
default-timeout=0            # critical sticks until dismissed
```

Notes:
- `padding=6,12` — comma form on recent mako; if rejected, fall back to space form.
  Verify on first install.
- `format` uses Pango markup: bold summary + muted body, mirroring the bar's
  active/muted text contrast.
- `height=32` caps the popup; Pango ellipsizes long bodies. If this proves too tight in
  daily use, drop the cap and accept growth — alignment rule still holds, box just grows
  downward.

## Notifications singleton

`quickshell/.config/quickshell/Notifications.qml`:

```qml
pragma Singleton
import Quickshell
import Quickshell.Io

// mako DND state. dnd=true → mode=do-not-disturb (popups suppressed; history still
// accrues). Same shape as Radio.qml / SuspendInhibit.qml.
Singleton {
    id: root
    property bool dnd: false

    function refresh() { modeGet.running = true; }
    function toggle() {
        modeToggle.command = ["makoctl", "mode", "-t", "do-not-disturb"];
        modeToggle.running = true;
        root.dnd = !root.dnd;   // optimistic; refresh confirms on next CC open
    }

    Process {
        id: modeGet
        command: ["sh", "-c", "makoctl mode 2>/dev/null | grep -q do-not-disturb && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "1" }
    }
    Process { id: modeToggle }
}
```

Behaviour:
- `refresh()` is called from `cc.refresh()` (CC `onVisibleChanged`) — same pattern as
  every other singleton.
- `toggle()` flips state optimistically. If mako isn't running, `makoctl` exits non-zero
  silently; the next `refresh()` corrects the displayed state.
- No periodic polling — DND state only changes via this toggle or `makoctl` from
  outside, both rare, so re-probing on CC open is enough.

## CC row insertion

New row "Quiet" between Auto-suspend (4) and BT (was 5):

```qml
// 5 — Quiet (mako DND)
CcToggleRow {
    cc: cc; rowIndex: 5; label: "Quiet"
    on: Notifications.dnd
    onToggled: Notifications.toggle()
}
```

Row table (post-change):

| index | row                 |
|------:|---------------------|
| 0     | Brightness          |
| 1     | Volume              |
| 2     | Airplane            |
| 3     | Warm                |
| 4     | Auto-suspend        |
| **5** | **Quiet (new)**     |
| 6     | BT                  |
| 7     | Wifi                |
| 8     | Output              |
| 9     | Power profile       |
| 10    | Power session footer (Lock · Logout · Sleep) |
| 11    | Power system footer (Hibernate · Reboot · Shutdown) |

### Mechanical shifts in `ControlCenter.qml`

Every downstream row index, switch case, and modulus bumps by 1:

- `advanceRow`: `% 9` → `% 10`; footer arithmetic `9 + ((… - 9 + dir + 2) % 2)`
  → `10 + ((… - 10 + dir + 2) % 2)`; gate `cc.focusedRow >= 9` → `>= 10`
- `dispatchHL` switch cases: 5→6, 6→7, 7→8, 8→9, footer 9/10 → 10/11
- `handleEnter` switch cases: same shifts
- `armOrFire(rowIndex, col, (rowIndex - 9) * 3 + col)` →
  `(rowIndex - 10) * 3 + col`
- `listLen` / `openList`: `openRow === 5 / 6 / 7` → `6 / 7 / 8`
- `Connections { target: WifiCtl/BtCtl/AudioCtl }`: openRow checks bump by 1
- `refresh()`: add `Notifications.refresh();`
- Header comment block (the "Rows" map at the top): rewrite to include row 5 Quiet and
  bump 5..8 → 6..9, 9..10 → 10..11
- `Item id: powerSection` comment "rows 9 & 10" → "rows 10 & 11"; `PowerGridRow`
  `rowIndex: 9 / 10` → `10 / 11`

No new files need to be created in CC beyond the singleton — `CcToggleRow` already
covers the visual shape.

## Niri spawn

`niri/.config/niri/config.kdl`:

```kdl
spawn-at-startup "mako"
```

Place adjacent to existing `swaybg` / `swayidle` lines (cosmetic, not load-bearing).

mako is short-lived as a process: niri kills it on session exit; no systemd unit needed.

## CONTEXT.md updates

- Stack table: add a `mako` row — purpose "notification daemon", deploy via stow
  `mako/`, config at `~/.config/mako/config`, runtime spawned by niri.
- Singletons list: add `Notifications` — wraps `makoctl mode`, refreshed on CC open.
- ControlCenter row map: include row 5 Quiet, renumber downstream rows.
- Drop the existing note about swaync being "not configured" — replace with the mako
  paragraph above.

## Pacman dependency

`mako` (official repo). No AUR. Install before first run.

## Out of scope

- **Notification history UI** — `makoctl history` works from CLI; a CC row for it is
  deferred (no concrete need yet).
- **Per-app rules** — mako supports them, but the defaults are fine for now; revisit
  if a chatty app shows up.
- **Bar icon for DND state** — CC is the only surface, per todos.txt 2d.
- **Sound** — mako can invoke a command on notify; leaving silent for now.

## Acceptance (mirrors todos.txt "done")

1. `notify-send hi there` renders in the Sky Paper palette, top-left, pixel-aligned to
   where a niri window's border-outer corner would sit.
2. CC row 5 "Quiet" toggles DND; while on, `notify-send` produces no popup (history
   still records); while off, popups resume.
3. mako autostarts on niri login (`pgrep -x mako` after fresh login).
4. Existing CC keyboard nav (hjkl/Enter) reaches and operates the new row; downstream
   rows still work (Wifi password flow, BT pairing, Output picker, Power footer).
5. `pacman -Qi mako` returns installed.
6. Feature branch merged into `laniakea` after manual verification.
