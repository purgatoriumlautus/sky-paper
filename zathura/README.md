# zathura — Sky Paper

Sky Paper themed zathura (PDF / ePub / XPS / CBZ viewer). Stow package.

## Deploy

```bash
cd ~/dotfiles && stow zathura     # symlinks ~/.config/zathura → here
./zathura/install.sh              # pacman pkgs + xdg-mime defaults (sudo)
```

## Files

- `.config/zathura/zathurarc` — Sky Paper colors (palette via `PALETTE.md`),
  Terminess 11 for statusbar/inputbar, hjkl/J/K/gg/G stock binds kept,
  `adjust-open = width` for sane first paint.

## Notes

- **Backend:** `zathura-pdf-mupdf` (renders PDF + ePub + XPS + CBZ + FB2).
  Only one backend can be active at a time; if you ever swap to
  `zathura-pdf-poppler` you must `pacman -Rns zathura-pdf-mupdf` first.
- **Default app:** `install.sh` runs `xdg-mime default` for PDF / ePub / XPS /
  CBZ etc., so yazi's `o` (open with default) and firefox "open with system
  handler" route here.
- **Recolor mode (`r`):** off by default. Toggles to invert page colors
  using `recolor-lightcolor` / `recolor-darkcolor` from the palette;
  `recolor-keephue = true` keeps figures readable.
- **Font:** Terminess Nerd Font Mono 11 in the statusbar / inputbar
  (matches kitty/bar). Native bitmap size — see
  [[reference-terminess-native-sizes]].
- **GTK chrome:** zathura is GTK3, so dialogs (open/save) inherit the
  `gtk/` stow pkg theme automatically.

## Cheatsheet

See `CHEATSHEET.txt` for stock binds.
