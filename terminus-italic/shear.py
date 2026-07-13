#!/usr/bin/env python3
# Shear a Terminus BDF into a slanted (italic) BDF, pixel-quantized.
# Each pixel row is shifted right proportional to its height above baseline.
# SLANT is the per-unit-height shift (0.20 = default Terminus-ish lean).
import sys, os

SLANT = float(os.environ.get('SLANT', '0.20'))
src, dst = sys.argv[1], sys.argv[2]
lines = open(src).read().split('\n')
out, i, n = [], 0, len(lines)

while i < n:
    line = lines[i]
    if not line.startswith('STARTCHAR'):
        out.append(line); i += 1; continue
    # collect the glyph block up to BITMAP
    block = []
    while not lines[i].startswith('BITMAP'):
        block.append(lines[i]); i += 1
    i += 1  # skip BITMAP
    bmp = []
    while not lines[i].startswith('ENDCHAR'):
        bmp.append(lines[i].strip()); i += 1
    # i now at ENDCHAR
    bbx = [b for b in block if b.startswith('BBX')][0].split()
    w, h, xoff, yoff = int(bbx[1]), int(bbx[2]), int(bbx[3]), int(bbx[4])

    pix = set()
    for r, hexs in enumerate(bmp):
        if not hexs:
            continue
        val = int(hexs, 16); nbits = len(hexs) * 4
        for c in range(w):
            if (val >> (nbits - 1 - c)) & 1:
                y = yoff + (h - 1 - r)          # pixel row height above baseline
                pix.add((c + round(SLANT * y), r))

    if pix:
        minx = min(p[0] for p in pix); maxx = max(p[0] for p in pix)
        neww = maxx - minx + 1; newxoff = xoff + minx
        bpr = (neww + 7) // 8                    # bytes per row (BDF pads right)
        newbmp = []
        for r in range(h):
            v = 0
            for (px, py) in pix:
                if py == r:
                    v |= 1 << (bpr * 8 - 1 - (px - minx))
            newbmp.append(format(v, '0{}X'.format(bpr * 2)))
    else:
        neww, newxoff, newbmp = w, xoff, bmp

    for b in block:
        out.append('BBX {} {} {} {}'.format(neww, h, newxoff, yoff)
                    if b.startswith('BBX') else b)
    out.append('BITMAP'); out.extend(newbmp); out.append('ENDCHAR')
    i += 1

open(dst, 'w').write('\n'.join(out))
