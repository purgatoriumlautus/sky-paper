# qs-launcher — design

**Date:** 2026-05-21
**Branch:** `qs-launcher`
**Closes:** todos.txt #4 (app launcher / dmenu rethink). Supersedes the tofi
re-style ladder (4a–4d): builds the qs-native launcher directly.

## Why

Tofi has sub-frame cold-start but looks cramped and is touched on every app
launch. Re-styling it (#4a) is cheap but still tofi. The decisive insight:
**the shell already runs as one persistent `qs` process** (`shell.qml` =
`Scope { Bar {} LockScreen {} }`, PID resident from `spawn-at-startup "qs"`).
A launcher added as a third child of that `Scope` opens by toggling a
`PopupWindow`'s visibility — **no process spawn, no Qt cold-start** — exactly
how `ControlCenter` opens today. So the qs-native launcher matches tofi's
latency *and* gets `Theme.qml` palette/font for free, while killing the tofi
dependency.

## Architecture

Mirrors the existing view/backend split (`WifiRow` ↔ `WifiCtl`,
`ControlCenter` ↔ `Radio`/`Brightness`/…):

- **`AppLauncher.qml`** — `pragma Singleton`, backend. Owns:
  - the app model (wraps `DesktopEntries.applications`),
  - the live `query` → `results` computation (fuzzy + frecency),
  - frecency persistence,
  - calculator evaluation,
  - run-command fallback,
  - `launch(entry)` / `run(cmd)` / `copyResult(text)` actions.
- **`Launcher.qml`** — `PopupWindow`, view. Field + ListView + open/close
  animation + key dispatch. UI only; all state/logic delegates to
  `AppLauncher`.
- **`shell.qml`** — add `Launcher {}` as a third child of the `Scope`.
- **`IpcHandler { target: "launcher" }`** — `toggle()` / `open()` / `close()`,
  same shape as the `controlcenter` handler in `Bar.qml`.

`shell.qml` must be `touch`ed after adding the new QML files so live-reload
regenerates qmldir (known gotcha).

## Glyph & bar integration

- New token (e.g. `Theme.launcherGlyph: "Δ"`) — the launcher glyph, paired
  with the CC's `λ`. `Δ` is a core-Terminus letter → bitmap-crisp. Keep it a
  swappable property.
- **Rest state:** bar center = `Clock` (unchanged).
- **Open (`Mod+D`):** `Clock` fades/slides out; the `Δ` glyph appears and
  slides from center to the **left edge** of the input box, becoming the
  field's left adornment; the input grows to its right, initially empty.
- **Close:** input collapses, `Δ` returns to center and becomes the `Clock`
  again.

Implementation note: the bar-center is a cross-fade between two states driven
by `launcher.visible`. The `Clock` and the launcher's open animation are
coordinated so the center never shows both at once. Integer-snap any animated
center x/y at rest so the clock text stays crisp (existing `Math.round`
pattern in `Bar.qml`).

## Popup layout

- `PopupWindow` anchored to the bar (`anchor.window: bar`), horizontally
  centered (`anchor.rect.x = round((bar.width - w)/2)`), dropping from
  `anchor.rect.y = bar.height`. Mirrors how CC anchors under the bar.
- Box: `Theme.boxFill` background, 1px `Theme.accentSoft` border, square
  corners (corner-radius 0, consistent with the rice), generous padding.
- Top row: `Δ  >  <TextInput>` — reuse `Field.qml` for the `> input` pair,
  glyph to its left.
- Below: a `ListView` of results, **max 5 visible**, height animates with the
  result count (fade + slide, ~200ms OutCubic) like the CC power section.
- **Empty query → empty list** (box is just the input row). Results appear
  only as you type.

## Interaction (arrows + Tab)

The `TextInput` always holds focus; typing filters live. Key dispatch in the
popup's `Keys.onPressed` (typing is *not* intercepted — only nav/commit/close):

| Key | Action |
|---|---|
| `Down` / `Tab` | select next (wraps) |
| `Up` / `Shift+Tab` | select previous (wraps) |
| `Enter` | commit selected row (launch app / run command / copy calc result) |
| `Esc` | close launcher |

Selection resets to index 0 on every query change. `onVisibleChanged` on open:
clear field, reset selection, then `field.input.forceActiveFocus()` — set
focus *after* visibility flips (CC `onVisibleChanged`-resets-focus gotcha).

## Matching & ordering

- **Fuzzy subsequence** match against app display names (case-insensitive):
  `fx` matches `firefox`. Score by match tightness (contiguity / earliness)
  so closer matches rank higher.
- **Frecency** re-ranks matches: `score = matchScore` blended with a
  frequency×recency term from launch history. Ties broken alphabetically.
- **Persistence:** `~/.local/state/quickshell/launcher-frecency.json`,
  `{ "<appId>": { "count": N, "last": <epoch> } }`, read/written via
  `Quickshell.Io.FileView`. `launch()` increments `count` and sets `last`
  before `.execute()`. File is created on first launch if absent; corrupt/
  missing file degrades to empty history (no crash).

## Three modes in one field

1. **Apps (default).** Fuzzy + frecency over `DesktopEntries`. `Enter`
   launches via the entry's `.execute()`.
2. **Calculator (auto-detected).** Active when the trimmed query is **pure
   arithmetic** — matches `^[\d.\s+\-*/%()]+$` **and** contains at least one
   operator (`+ - * / %`). One result row shows the evaluated value; `Enter`
   copies it via `wl-copy`. No `=` prefix.
   - `1414+2313` → `3727`; `(2+3)*4` → `20`.
   - `2048` (bare number, no operator) → stays **app search** (so apps with
     digits in their name are still findable).
   - `7-zip`, `0 A.D.` → contain letters → not pure arithmetic → app search.
   - Eval safety: the regex gate guarantees an arithmetic-only charset before
     evaluation; reject (show nothing) on parse error or division anomalies.
3. **Run-command (fallback).** When the query matches **no** app (and isn't
   calc), show a single row `» run: <query>` that executes `<query>` via
   `sh -c` on `Enter`. Never a dead-end empty list.

## Trigger plumbing

- niri `config.kdl` line 447:
  `Mod+D … { spawn "tofi-drun"; }` →
  `Mod+D hotkey-overlay-title="Run an Application" { spawn "qs" "ipc" "call" "launcher" "toggle"; }`
- `IpcHandler` `toggle()` mirrors `cc.toggleCc()` (250ms debounce, open/close
  animation guard).

## Removing tofi

Safe — both tofi files are dead once Mod+D points at the launcher:

- `tofi/.config/tofi/config` — only consumer was Mod+D (rewired above).
- `tofi/.config/tofi/power.config` — **already orphaned**: the power menu
  moved into the CC hideable section (CONTEXT.md notes the old
  `power-menu.sh` + tofi `power.config` as "удалены"; the file lingers with no
  binding).

Steps:
1. Remove the `tofi/` stow package (the symlink `~/.config/tofi` and the repo
   dir). Mind the symlink-clobber gotcha — `stow -D tofi` cleanly, don't `rm`
   through the symlink.
2. `pacman -Rns tofi`.
3. Update `CONTEXT.md`: replace the `tofi` Stack-table row with the
   qs-launcher; drop tofi from the "Актуальные на laniakea" stow list.
4. Update `PALETTE.md`: replace the `tofi:` section with the launcher's
   surfaces (boxFill bg, 1px accentSoft border).
5. Update `todos.txt` #4 → done with a one-line note (qs-native launcher,
   ladder superseded).

## Out of scope (YAGNI)

- App icons (rice is icon-free; text-only by design).
- Calc beyond arithmetic (no sqrt/trig/unit-conversion).
- Plugins / web-search / emoji modes.
- Mouse interaction beyond what `PopupWindow` gives for free (keyboard-driven,
  like the rest of the shell). Click-to-open on the bar is not added (glyph
  only exists while open); entry is `Mod+D`.

## Success criteria

- `Mod+D` opens the launcher in a frame (no perceptible cold-start), empty.
- Typing filters live; frequently-launched apps float to the top over time
  (frecency file grows and is honored across `qs` reloads).
- `Down/Tab` / `Up/Shift+Tab` cycle selection; `Enter` launches; `Esc` closes.
- `1414+2313` shows `3727`, `Enter` copies it; `2048` still finds an app.
- A non-app query runs as a command via the `» run:` row.
- Glyph `Δ` is bitmap-crisp; clock↔glyph transition animates cleanly both ways.
- `pacman -Qi tofi` → "not installed"; `~/dotfiles/tofi/` gone; CONTEXT,
  PALETTE, todos updated.
- `qs` reload shows no QML parse errors; no leaked processes.
