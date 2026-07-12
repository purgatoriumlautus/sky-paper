#!/usr/bin/env bash
# Build the importable Telegram Desktop theme from the palette source.
# Output: flexoki-dark.tdesktop-theme — a zip of:
#   colors.tdesktop-theme  (the palette)
#   background.png         (solid #100F0F tile → solid paper-black chat area)
# No image tooling required: the tile is written by a dependency-free PNG encoder.
set -euo pipefail
cd "$(dirname "$0")"

out=flexoki-dark.tdesktop-theme
bg=background.png

# Solid #100F0F PNG (regenerated each build so it stays reproducible).
python3 - "$bg" <<'PY'
import sys, struct, zlib
w = h = 64
r, g, b = 0x10, 0x0f, 0x0f
raw = b"".join(b"\x00" + bytes((r, g, b)) * w for _ in range(h))  # filter byte + RGB row
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))  # 8-bit RGB
png += chunk(b"IDAT", zlib.compress(raw, 9))
png += chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY

rm -f "$out"
zip -q -X "$out" colors.tdesktop-theme "$bg"
echo "built $out ($(du -h "$out" | cut -f1))"
