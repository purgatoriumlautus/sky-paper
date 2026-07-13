#!/usr/bin/env bash
# Regenerate fonts/TerminusItalic-*.ttf from the installed Terminus bitmaps.
#
# Terminus ships no italic. This builds one: shear the 16px bitmap strike,
# then trace one square outline per pixel so it stays crisp at font_size 12
# (= 16px) in kitty, which only loads sfnt faces that carry real outlines.
#
# Needs: fontforge (for pcf->bdf and the outline build), terminus-font
# (source strikes). SLANT is the per-unit lean; smaller = more upright.
#
# Run from anywhere; writes into this module's fonts/. Deploy with install.sh.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLANT="${SLANT:-0.05}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v fontforge >/dev/null || { echo "need fontforge" >&2; exit 1; }

# ter-x16{n,b} = Terminus 16px normal/bold strikes shipped by terminus-font.
for v in n b; do
    gz="/usr/share/fonts/misc/ter-x16${v}.pcf.gz"
    [[ -f "$gz" ]] || { echo "missing $gz (install terminus-font)" >&2; exit 1; }
    gunzip -c "$gz" > "$WORK/ter-x16${v}.pcf"
    # fontforge appends the pixel size -> ter16${v}-16.bdf
    fontforge -lang=ff -c 'Open($1); Generate($2, "", 0x10000000)' \
        "$WORK/ter-x16${v}.pcf" "$WORK/ter16${v}.bdf" >/dev/null 2>&1
done

SLANT="$SLANT" python3 "$SRC/shear.py" "$WORK/ter16n-16.bdf" "$WORK/ter-i.bdf"
SLANT="$SLANT" python3 "$SRC/shear.py" "$WORK/ter16b-16.bdf" "$WORK/ter-bi.bdf"

fontforge -script "$SRC/build_ff.py" "$WORK/ter-i.bdf" \
    "$SRC/fonts/TerminusItalic-Regular.ttf" "Terminus Italic" "Italic"      >/dev/null 2>&1
fontforge -script "$SRC/build_ff.py" "$WORK/ter-bi.bdf" \
    "$SRC/fonts/TerminusItalic-Bold.ttf"    "Terminus Italic" "Bold Italic" >/dev/null 2>&1

echo "Built fonts/TerminusItalic-*.ttf at SLANT=$SLANT. Run install.sh to deploy."
