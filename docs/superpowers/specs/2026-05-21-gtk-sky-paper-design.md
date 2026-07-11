# GTK theme — Sky Paper, Win95 vibe

**Date:** 2026-05-21 · **Branch:** `gtk-sky-paper`

Make GTK apps match the system: **Sky Paper** palette (see `PALETTE.md`) with a
**Windows 95** chunky-bevel aesthetic (inspiration: Nashville96 / Chicago95) and
retro icons. Covers GTK3 *and* GTK4/libadwaita. Real surface today: `pavucontrol`
(GTK4) and Firefox's file dialog (GTK3 via the portal).

## Approach

Not a from-scratch theme and **not** Nashville96 itself (it's GTK2/3-only,
XFCE-oriented, archived). Instead: keep **Adwaita** as the structural base,
override its named colors to Sky Paper, then layer Win95 devices in pure CSS
(no PNG assets): 4-color beveled borders (raised buttons / sunken fields),
square corners, chunky scrollbars, square checks, dotted focus, solid sky
selection, beveled folder-tabs with a sky underline (kills Adwaita's blue).

Deployed as a GNU Stow package `gtk/`. dconf and the icon theme can't be stowed
files, so they're scripts (same rationale as `firefox/install.sh`).

## Files

- `gtk/.config/gtk-3.0/gtk.css` — Adwaita named-color overrides + Win95 bevel layer
- `gtk/.config/gtk-4.0/gtk.css` — libadwaita named-color overrides + same bevel layer
- `gtk/.config/gtk-{3,4}.0/settings.ini` — `gtk-theme=Adwaita`, prefer-light,
  `gtk-font-name=Terminess Nerd Font Mono 12` (12pt → 16px @96 DPI, a native
  Terminess size = the bar). Caveat: display scale ≠ 1 lands off-grid → fuzzy.
- `gtk/apply.sh` — dconf: `color-scheme=prefer-light`, gtk-theme, fonts, and
  `icon-theme=Chicago95`. Run once after `stow gtk`.
- `gtk/icons-install.sh` — fetches Chicago95 (30MB/4000 files, not vendored),
  copies `Icons/Chicago95` → `~/.local/share/icons`, patches
  `Inherits=Adwaita,hicolor` (fallback for symbolics it lacks), rebuilds cache.
- `gtk/.stow-local-ignore` — keeps the two scripts out of `~`.

### Bevel palette (Sky Paper)
face `#E4DED0` · highlight `#FFFFFF` · inner-shadow `#C5BFB5` · dark-edge `#7A716A`
· text `#1F1812` · selection/fill/title `#A8C0D5` · links/accent `#4A6F8E`.

## Firefox

The browser **chrome** is Firefox-drawn (its own engine), never GTK — by design;
GTK theming can't touch it (would need `userChrome.css`, out of scope). Only FF's
**dialogs** are GTK. `firefox/user.js` sets
`widget.use-xdg-desktop-portal.file-picker=1` so the file dialog uses the
portal's GTK3 chooser (themed, reloadable via portal restart) instead of FF's
bundled one (only re-themes on full FF restart).

## Verification

`pavucontrol` (GTK4) screenshotted + zoomed (`grim` → `ffmpeg crop/neighbor`):
beveled tabs/combobox/slider, sky underline, square corners, Terminess, retro
device icon, zero icon-fallback warnings. GTK3 css validated by restarting
`xdg-desktop-portal-gtk` (no CSS parse errors logged); no GTK3 demo app installed
to screenshot, but it mirrors the verified GTK4 file.

## Out of scope (YAGNI)

Firefox chrome theming (userChrome), GTK2 apps, XFCE/metacity WM decorations
(niri ignores them), per-app CSS overrides, recoloring icons to the exact palette.
