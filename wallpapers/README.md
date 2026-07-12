# wallpapers — sources (not deployed; niri points at ~/Pictures/wallpapers)

- `mntvagaflexoki.png` — current. Vagabond mountains, inverse engraving:
  ink strokes → muted `#878580`, paper → bg `#100F0F`. Source:
  `~/Pictures/wallpapers/mntvagabw.png` (b&w original, not in repo).
- `katanaflexoki.png` — ASCII katana, purple-400 on black (spare).
- `clouds.png` — Sky Paper artifact.

## Duotone recipe (any b&w image → Flexoki)

ffmpeg `curves` with two points per channel maps black→A, white→B
(values are hex/255). Inverse-muted (current wallpaper):

```sh
ffmpeg -i in.png -vf "format=rgb24,curves=r='0/0.529 1/0.0627':g='0/0.522 1/0.0588':b='0/0.502 1/0.0588'" -frames:v 1 out.png
```

Variants tried and kept viable: bright inverse (strokes `#CECDC3`:
`0/0.808:0/0.804:0/0.765`), warm paper light (`#100F0F`→`#C7C4BB`:
swap the endpoints). Light wallpapers need barBg alpha ≥ E6 and window
opacity ≥ 0.98 — see Theme.qml / config.kdl comments.
