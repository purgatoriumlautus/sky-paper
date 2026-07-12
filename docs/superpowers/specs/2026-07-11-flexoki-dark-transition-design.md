# celestia → Flexoki Dark transition — design

**Date:** 2026-07-11
**Goal:** Retire the light Sky Paper palette; move the whole system to
**Flexoki dark** (flexoki.com) permanently. No light/dark toggle — decided
and closed (YAGNI: the light palette simply didn't stick).

**Working mode:** Ars writes every config change himself; Claude guides and
reviews. Specs/plans are the only files Claude authors. No commits by Claude.

---

## 1. Locked decisions

- **No toggle.** Single permanent dark palette. A toggle would tax every
  future palette tweak (two themes to maintain) for a use-case that doesn't
  exist.
- **Palette = Flexoki dark, adopted as-is.** Source of truth: flexoki.com
  (+ `kepano/flexoki` on GitHub). Base scale ("dark paper + ink") mapped onto
  the existing role skeleton (bg / bg-alt / border-dim / muted / fg); all
  **8 accents** kept, dark-theme tones (the 400 row). Official Flexoki syntax
  spec drives nvim highlighting. Rationale: Flexoki shares Sky Paper's
  paper-first, contrast-calculated philosophy — we transfer a palette, we
  don't design one. (Revisit "shrink to 2 accents" only if the full set
  proves too loud in practice.)
- **Primary UI accent: purple-400 `#8B7EC8`** — niri active border, active
  kitty tab, tmux current window, launcher/CC selection, bar markers.
  Contrast vs bg `#100F0F` ≈ 5.4:1 (AA). Deliberate warm-paper /
  cool-accent contrast (kanagawa-style move), chosen with eyes open.
- **GTK goes dark on all three layers** (they serve different app
  generations and all must flip):
  1. switches: `settings.ini` `gtk-application-prefer-dark-theme` (GTK3) +
     `apply.sh` gsettings `color-scheme` (libadwaita/GTK4, Firefox via portal);
  2. named-color overrides in `gtk-3.0/gtk.css` + `gtk-4.0/gtk.css`
     remapped to Flexoki dark;
  3. Win95 bevel chrome rebuilt from the Flexoki base scale, preserving
     relief order `hi > face > sh > dk` (current `#FFFFFF` highlight would
     glow neon on dark faces; real Win95 dark schemes used
     lighter-than-face, not white).
- **Invariants untouched:** squared corners, no blur, palette-matched
  animation, Terminess/Unifont, Chicago95 cursor + icons.
- **Obsidian:** drop `sky-paper.css`, use the official Flexoki community
  theme (Flexoki is by Obsidian's Steph Ango). vimrc stays.

## 2. Order of work

**Step 0 — PALETTE.md rewrite (blocks everything else).** Same structure as
today: Base table with roles + contrast ratios, Syntax, Terminal-16,
Per-tool. No config edits until it's done — otherwise the mapping gets
invented ad-hoc per file.

Then, layer by layer; each step is deployable (stow / install.sh) and
individually revertible via git. Living a few days with a mixed system is
acceptable.

1. **Terminal stack:** kitty → tmux → nvim (+ fish, fastfetch, yazi) —
   fastest feedback loop.
2. **Compositor layer:** niri → quickshell (bar, ControlCenter, launcher,
   lockscreen) → mako.
3. **Apps:** gtk (3 layers) → firefox → zathura → mpv → obsidian.
4. **Periphery:** quickshell-greeter → crossgrub.

## 3. Open decisions (to resolve during Step 0 / on the way)

- **Terminal-16 mapping:** Flexoki documents its own ANSI-16 choice —
  review it consciously rather than copy blindly (Sky Paper deliberately
  collapsed red/green/cyan; Flexoki won't).
- **Win95 bevel quad** (`face/hi/sh/dk`): pick 4 tones from the Flexoki
  base scale keeping the relief order.
- **Theme name in files:** "Sky Paper" appears in filenames and comments
  (`sky-paper.css`, `sky-paper.tmTheme`, Theme.qml comments…). Default:
  rename to flexoki-dark as each module is touched.
- **Wallpaper:** RESOLVED — Ars had already made `katanaflexoki.png`
  (ASCII katana in purple-400 on black) and pointed niri's swaybg at it;
  source copied into `wallpapers/`. clouds.png stays in the repo as a
  Sky Paper artifact until Ars decides to drop it.

## 4. Documentation updates

- PALETTE.md — rewritten in Step 0.
- CONTEXT.md §2 ideology lines ("Sky Paper invariants", "GTK widgets stock
  Adwaita light") updated in the same sitting as the corresponding deploy,
  per §META rules.
