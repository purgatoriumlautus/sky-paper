# yazi — Flexoki Dark

Flexoki Dark themed yazi (file manager). Stow package.

## Deploy

```bash
stow yazi                       # symlinks ~/.config/yazi → here
./yazi/install.sh               # optional: video/PDF thumbnail helpers (sudo)
```

## Files

- `theme.toml` — Flexoki Dark colors over yazi's `theme-dark.toml` preset.
  UI chrome, filetype filename colors, and the `[icon]` glyph table with all
  `fg` stripped so each glyph inherits its filename's palette color.
- `flexoki-dark.tmTheme` — code-preview syntax, mirrors the nvim palette roles.
- `yazi.toml` — behavior overrides (`linemode = "size"`); rest are defaults.

## Notes

- **Icons:** Nerd Font glyphs kept (kitty's font is Terminess Nerd Font Mono).
  They may render soft at bitmap sizes — accepted trade-off.
- **Image preview:** kitty graphics protocol, auto-detected. Native image
  formats need nothing extra.
- **Video / PDF preview:** needs `ffmpegthumbnailer` + `poppler` —
  run `install.sh`. Without them, yazi shows file info instead of a thumbnail.
- **Keybinds:** every one of them, stock and overridden, is in
  `docs/keybinds-reference.md` §7.
- **Delete:** `d` trashes (recoverable), `D` deletes permanently — the same
  way round as the nvim file tree, which had them inverted until 2026-09.
- **Regenerate the icon table** (if upstream changes): re-run Task 5 of the
  plan — fetch `theme-dark.toml`, `sed -E 's/, fg = "[^"]*"//g'` the
  `[icon]`→EOF slice, replace the section in `theme.toml`.
