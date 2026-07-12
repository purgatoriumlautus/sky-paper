# wallpapers — sources (not deployed; niri points at ~/Pictures/wallpapers)

- `mntvagaflexoki.png` — current. Vagabond mountains, inverse engraving:
  ink strokes → muted `#878580`, paper → bg `#100F0F`. B&w original:
  `mntvagabw.png`.
- `infiniteflexoki.png` — Musashi "do you see how infinite you are?",
  same muted-inverse treatment, near-solid `#100F0F` field (browser bg).
  B&w original: `infinite.png` — its scan had an off-white page box,
  killed by clipping near-whites (`lutrgb` stage below) before the duotone.
- `katanaflexoki.png` — ASCII katana, purple-400 on black (spare).
- `clouds.png` — Sky Paper artifact.

## Duotone recipe (any b&w image → Flexoki)

ffmpeg `curves` with two points per channel maps black→A, white→B
(values are hex/255). Inverse-muted (current wallpaper):

```sh
ffmpeg -i in.png -vf "format=rgb24,curves=r='0/0.529 1/0.0627':g='0/0.522 1/0.0588':b='0/0.502 1/0.0588'" -frames:v 1 out.png
```

If the source is a scan with an off-white page tone, clip near-whites
first so they land on the same black (insert before `curves`):

```
lutrgb=r='if(gt(val,235),255,val)':g='if(gt(val,235),255,val)':b='if(gt(val,235),255,val)',
```

Variants tried and kept viable: bright inverse (strokes `#CECDC3`:
`0/0.808:0/0.804:0/0.765`), warm paper light (`#100F0F`→`#C7C4BB`:
swap the endpoints). Light wallpapers need barBg alpha ≥ E6 and window
opacity ≥ 0.98 — see Theme.qml / config.kdl comments.
