# yazi-sky-paper — design

**Date:** 2026-05-21
**Branch:** TBD (feature branch off `laniakea`, e.g. `yazi-sky-paper`)
**Closes:** todos.txt #17 (yazi config). 17a (Sky Paper theme) + 17c (kitty
image preview) fully; 17b reinterpreted — see "Decisions" below.

## Why

Yazi runs at stock defaults — dark theme, mismatched code-preview syntax
colors, no awareness of the Sky Paper palette every other tool already uses
(nvim, tmux, kitty, quickshell). It's the last day-to-day TUI that doesn't
match. This brings it in line with a hand-authored `theme.toml` + a
`.tmTheme` for code preview, and turns on the previews kitty can render.

## Decisions (locked during brainstorming)

- **Nerd Font icons: kept, neutralized to palette.** Yazi's default glyph
  set stays on, but the upstream `[icon]` table is vendored with every `fg`
  stripped so each glyph inherits its filename's palette color (dirs = deep
  sky, exec = dark, media = muted) rather than the upstream rainbow. (kitty's
  primary font is `Terminess Nerd Font Mono`, which carries the glyphs. The
  known bitmap-mushiness caveat was acknowledged and accepted.)
- **Image preview: kitty graphics protocol**, auto-detected by yazi. Native
  image formats work out of the box. Install `ffmpegthumbnailer` + `poppler`
  so video and PDF previews also work.
- **Delete: stock.** `d` → trash (yazi's built-in XDG-trash, no external
  binary), `D` → permanent delete. No custom keymap needed.
- **Preview pane: always on** (yazi's default 3-column layout). No
  toggle-pane plugin, no preview-toggle bind. This replaces the todo's
  "bind preview-pane toggle" (17b) — the chosen behavior is always-visible
  preview, so there is nothing to bind.
- **No `keymap.toml`.** hjkl + `d`/`D` are all stock; nothing to override.
- **Direct `theme.toml`, not a flavor package.** Yazi 26.x flavors are for
  *distributable* themes; for personal dotfiles a direct `theme.toml` plus a
  referenced `.tmTheme` is simpler and idiomatic.

## Package layout

Stow package mirroring `nvim/` and `kitty/`:

```
~/dotfiles/yazi/.config/yazi/
  theme.toml          # all Sky Paper colors + icon recolor + syntect_theme ref
  yazi.toml           # behavior: linemode, sort, preview adapter (auto)
  sky-paper.tmTheme   # code-preview syntax theme (matches nvim roles)
  README.md           # what this is + the ffmpegthumbnailer/poppler note
  install.sh          # pacman -S --needed ffmpegthumbnailer poppler
```

Deployed via the repo's existing stow flow → `~/.config/yazi/` (directory
symlink or per-file, matching how the rest of the repo is stowed).

**No `keymap.toml`** is shipped (stock keymap is correct).

## File specs

### theme.toml

Palette source of truth is `PALETTE.md`. Sections to color:

- **`[mgr]`** — `cwd` = `accent-text #4A6F8E`; `hovered` bg `accent-soft
  #A8C0D5` fg `fg #1F1812`; `preview_hovered` underline; `find_keyword` /
  `find_position` = deep sky on muted; `marker_*` (copied/cut/marked/
  selected) using the palette (selected = `accent-soft`); `count_*` badges
  fg `#1F1812` on `accent-soft`/`muted`; `border_style` = `border-dim
  #C5BFB5`.
- **`[mgr] syntect_theme`** — path to `~/.config/yazi/sky-paper.tmTheme`.
- **`[mode]`** — NORMAL/SELECT/UNSET indicator bg/fg. Active mode bg
  `accent-soft #A8C0D5` fg `#1F1812` bold; UNSET muted. (Mirrors the
  tmux/launcher "active = sky box, dark text" idiom.)
- **`[status]`** — separators and the `perm`/`progress` segments; bar in
  `bg-alt #E4DED0` zone, text `muted #7A716A`, active bits `#1F1812`.
- **`[select]`** / **`[input]`** / **`[cmp]`** (completion) /
  **`[tasks]`** / **`[which]`** / **`[help]`** / **`[notify]`** — borders
  `border-dim`, titles `accent-text`, active/hovered row `accent-soft` bg +
  `#1F1812` fg, hints `muted`. Notify: info/warn/error all in-palette (no
  red — use `#1F1812` bold for error, matching PALETTE's "no red" rule).
- **`[filetype]`** — keep yazi's default icon rules but set `fg` on the
  rules to palette tones: directories `accent-text #4A6F8E`, symlinks
  `muted #7A716A` (orphan = `#1F1812` bold), exec `#1F1812` bold, media/
  archives `muted`, plain files `fg #1F1812`. Icons inherit these colors.

### sky-paper.tmTheme

A minimal `.tmTheme` (Sublime/TextMate plist XML) consumed by yazi's
syntect-based code preview. Scopes mapped to the exact roles PALETTE.md
already defines for nvim, so a file looks the same in yazi preview as in
nvim:

| tmTheme scope | color | role |
|---|---|---|
| global `background` | `#F0EBE0` | bg |
| global `foreground` / `caret` | `#1F1812` | fg |
| `comment` | `#7A716A` *(italic)* | comment |
| `keyword`, `keyword.control`, `storage` | `#4A6F8E` | keyword/conditional |
| `entity.name.type`, `entity.name.class` | `#1F1812` *(bold)* | type |
| `entity.name.function`, `support.function` | `#1F1812` | function |
| `string` | `#7A716A` | string |
| `constant.numeric`, `constant.language` | `#7A716A` | number/boolean |
| `constant.other` | `#1F1812` | constant |
| `keyword.operator` | `#7A716A` | operator |
| `variable`, `variable.parameter` | `#1F1812` | property/param |

Selection/line-highlight: `selection` = `border-dim #C5BFB5`.

### yazi.toml

Close to defaults, no surprises:

- `[mgr] linemode = "size"`, `show_hidden = false`, `sort_by = "alphabetical"`,
  `sort_dir_first = true`, `sort_sensitive = false` (or yazi defaults if they
  already match — only override what differs).
- `[preview]` — leave adapter on auto (kitty graphics auto-detected). Set
  reasonable `max_width` / `max_height` only if the default is wrong; default
  preferred.
- No `[opener]` / `[open]` overrides unless a default is broken.

Anything yazi already defaults correctly is left unset rather than restated.

### install.sh + README.md

`install.sh` follows the repo convention (`tlp/install.sh`, `keyd/install.sh`):
`set -euo pipefail`, `pacman -S --needed ffmpegthumbnailer poppler` (no
`--noconfirm` — never silent), idempotent, with a one-line revert note.
README states: what the package themes, the icon-font caveat, and that the
two thumbnail helpers are optional-but-recommended (yazi degrades to file
info without them).

## Testing / done criteria

Matches todos.txt #17 "done" line plus the locked decisions:

1. `yazi` opens; UI chrome (status, mode, borders, selection, which-key) is
   Sky Paper — no dark-theme leftovers.
2. Code preview of a source file shows Sky Paper syntax (deep-sky keywords,
   muted comments/strings, cream bg) — visually consistent with nvim.
3. Image preview renders inline via kitty graphics; after `install.sh`, a
   video and a PDF also show thumbnails.
4. hjkl navigation works; `d` trashes (recoverable), `D` permanently deletes
   with confirm.
5. Preview pane is always visible (3-column).
6. Stow symlink resolves to the repo; nothing clobbered (per the
   symlink-structure caveat in memory).

## Out of scope

- toggle-pane / any plugin (preview is always-on).
- custom keymap.toml.
- flavor package (using direct theme.toml).
- imagemagick (only needed for exotic formats like HEIC/SVG; not installed,
  not required for the done criteria).
