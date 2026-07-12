# telegram — Flexoki Dark theme for Telegram Desktop

Not a stow/install.sh module: Telegram Desktop themes are imported through
the app, not written to a config path. Palette source of truth: `../PALETTE.md`.

## Files

- `colors.tdesktop-theme` — the palette (467 vars, derived from tdesktop's
  night default, remapped to Flexoki Dark). Human-editable, git-reviewable.
- `background.png` — solid `#100F0F` tile (built), makes the chat area flat
  paper-black instead of Telegram's default pattern.
- `flexoki-dark.tdesktop-theme` — the importable theme (zip of the two above).
- `build.sh` — regenerates `background.png` + repacks the `.tdesktop-theme`.

## Install

Telegram Desktop imports a theme by *opening the file*, there is no config
path to stow:

1. Send `flexoki-dark.tdesktop-theme` to **Saved Messages** (drag it into the
   chat), or run `xdg-open flexoki-dark.tdesktop-theme`.
2. Click the file → **Apply theme**.

To tweak: edit `colors.tdesktop-theme`, run `./build.sh`, re-apply.

## Design notes (how the palette maps)

- **Bubbles are monochrome:** incoming `#1C1B1A` (bg-alt), outgoing `#343331`
  (ui) — both light ink. Purple is a *marker*, not a bubble fill, matching
  PALETTE.md (ui = message-bg role).
- **Accent = purple `#8B7EC8`:** send button, unread badges, active chat row,
  reply outlines, selection, ticks, focused input. Text *on* purple is always
  dark ink `#100F0F` (light fg on purple only reaches 2.2:1).
- **Links = blue `#66A0C8`**; inline code = cyan; the 8 group-member name
  colors map 1:1 onto the Flexoki accent ring (red→green→yellow→blue→purple→
  magenta→cyan→orange).
- **Chat background:** solid `#100F0F` via the bundled tile.
