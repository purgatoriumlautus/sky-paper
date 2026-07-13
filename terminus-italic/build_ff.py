#!/usr/bin/env python3
# Build a crisp monospace TTF from a (sheared) Terminus BDF by drawing one
# square outline per lit pixel. Squares land on a 128-unit grid so that at
# em=2048 (16px) each pixel == 128 units == exactly one screen pixel at 16px.
#   fontforge -script build_ff.py IN.bdf OUT.ttf "Family" "Style"
import fontforge, sys

inp, outp, family, style = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
bold = 'Bold' in style

PX   = 128
ASC  = 12 * PX          # 1536
DESC = 4 * PX           # 512  (FONTBOUNDINGBOX yoff = -4)
EM   = ASC + DESC       # 2048
CELL = 8 * PX           # 1024  fixed advance (8px cell)

def parse_bdf(path):
    g, lines, i = {}, open(path).read().split('\n'), 0
    while i < len(lines):
        if lines[i].startswith('STARTCHAR'):
            enc = bbx = None; bmp = []
            while not lines[i].startswith('ENDCHAR'):
                L = lines[i]
                if L.startswith('ENCODING'):
                    enc = int(L.split()[1])
                elif L.startswith('BBX'):
                    p = L.split(); bbx = (int(p[1]), int(p[2]), int(p[3]), int(p[4]))
                elif L.startswith('BITMAP'):
                    i += 1
                    while not lines[i].startswith('ENDCHAR'):
                        bmp.append(lines[i].strip()); i += 1
                    break
                i += 1
            if enc is not None and enc >= 0 and bbx:
                g[enc] = (bbx, bmp)
        i += 1
    return g

f = fontforge.font()
f.em = EM; f.ascent = ASC; f.descent = DESC
f.familyname = family
f.fontname   = family.replace(' ', '') + '-' + style.replace(' ', '')
f.fullname   = family + ' ' + style
f.weight     = 'Bold' if bold else 'Medium'
f.italicangle = -11

for enc, (bbx, bmp) in parse_bdf(inp).items():
    w, h, xoff, yoff = bbx
    g = f.createChar(enc)
    pen = g.glyphPen()
    for r, hexs in enumerate(bmp):
        if not hexs:
            continue
        val = int(hexs, 16); nbits = len(hexs) * 4
        for c in range(w):
            if (val >> (nbits - 1 - c)) & 1:
                x0 = (xoff + c) * PX; x1 = x0 + PX
                yb = (yoff + h - 1 - r) * PX; yt = yb + PX
                pen.moveTo((x0, yb)); pen.lineTo((x0, yt))
                pen.lineTo((x1, yt)); pen.lineTo((x1, yb)); pen.closePath()
    pen = None
    g.correctDirection()
    g.removeOverlap()
    g.width = CELL          # force AFTER drawing: glyphPen resets width to em

f.os2_stylemap = (0x21 if bold else 0x01)
f.appendSFNTName('English (US)', 'Family', family)
f.appendSFNTName('English (US)', 'SubFamily', style)
f.appendSFNTName('English (US)', 'Fullname', family + ' ' + style)
f.generate(outp)
