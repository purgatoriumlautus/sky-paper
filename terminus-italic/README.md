# terminus-italic

A crisp slanted italic for Terminus, which ships none.

kitty renders the Terminess/Terminus look from bitmaps embedded in an sfnt,
but its built-in italic fell back to Unifont (wrong face) or looked broken
(bad outline traces). This module builds a matching italic by shearing the
16px Terminus bitmap strike, then tracing **one square outline per pixel** —
so it carries real `glyf` outlines (kitty rejects bitmap-only faces) yet
stays pixel-crisp at `font_size 12` (= 16px), where each pixel lands on the
128-unit grid exactly.

Family `Terminus Italic`, styles `Italic` + `Bold Italic`. Monospace,
Cyrillic + box-drawing covered. Wired in `kitty/.config/kitty/kitty.conf`
(`italic_font` / `bold_italic_font`).

## Deploy

    ./install.sh          # copies fonts/*.ttf -> ~/.local/share/fonts + fc-cache

## Rebuild (only to change the slant)

    SLANT=0.05 ./build.sh   # default 0.05; smaller = more upright
    ./install.sh

Needs `fontforge` and `terminus-font` (source strikes at
`/usr/share/fonts/misc/ter-x16{n,b}.pcf.gz`). `build.sh` is the only reason
fontforge is a dependency — deploying just needs the shipped TTFs.

## Pieces

- `shear.py` — shears a Terminus BDF, shifting each pixel row right by
  `round(SLANT * height-above-baseline)`. Pixel-quantized (no anti-alias).
- `build_ff.py` — fontforge script: draws a square per lit pixel, merges
  overlaps, forces a fixed advance, tags the italic metadata, emits TTF.
- `fonts/` — the built faces (checked in so deploy needs no fontforge).
