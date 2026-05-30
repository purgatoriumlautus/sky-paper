# todos — celestia

Future work: things to implement, fix, or decide. Active list (state caveats that just
*describe* the system live in CONTEXT.md "Known Issues").

Format: `[ ]` open · `[~]` in progress · `[x]` done. Newest-relevant on top.

---

## Desktop / aesthetic

- [ ] **Default media player (MIME) — fix + restyle.** Two problems:
  1. *Inconsistent defaults.* `mpv` handles most audio/video, but **Firefox** is the
     registered default for `audio/flac` and `video/webm` (verified via `xdg-mime query
     default`). So some files open in a browser tab. Unify all `audio/*` + `video/*` on one
     player (edit `~/.config/mimeapps.list`, or `xdg-mime default`).
  2. *Player looks off-theme.* Stock mpv UI is bare and doesn't match Sky Paper. Options to
     weigh: keep mpv and style it (`~/.config/mpv/mpv.conf` + an OSC like **uosc** or
     **mpv-osc-modern**), or pick a different player. Decide direction first, then style.
  - Stow a new `mpv/` (and maybe a separate music player) module once settled.

- [ ] **wlsunset night light.** Installed but not running/configured. Wire it into niri
      `spawn-at-startup` with day/night temps + the local lat/long, if wanted.

## Cleanup / housekeeping

- [ ] **Stop orphaned `mpd.service`** (user) — process still running though mpd was removed.
      `systemctl --user stop mpd`; confirm nothing re-spawns it.
- [ ] **Commit untracked files** into `~/celestia`: `CONTEXT.md`, `CLAUDE.md`, `todos.md`,
      and the `xfce4/` Thunar migration.
- [ ] **Regenerate `packages.txt`** — it's slightly behind live `pacman -Qe`.
- [ ] **`bun` decision** — installed at `~/.bun` but not on PATH. Export it (fish) or remove
      the dir.
- [ ] **Font de-dup review** (small win): `terminus-font` (X11 bitmap) is likely redundant
      next to `ttf-terminus-nerd` on pure-Wayland; `otf-unifont` (~16 MiB) only worth
      keeping if you actually hit missing glyphs.

## Storage / hardware

- [ ] **Swap (sdb2, 4G)** exists but is inactive — activate (`swapon` + fstab) if wanted.
- [ ] **sda BitLocker drive (931.5G)** — plan its future use (mount read-only via dislocker,
      or repurpose).

## Maintenance (recurring)

- [ ] **dnscrypt-proxy blocklist** — regenerate periodically.
