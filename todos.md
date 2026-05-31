# todos — celestia

Future work: things to implement, fix, or decide. Active list (state caveats that just
*describe* the system live in CONTEXT.md "Known Issues").

Format: `[ ]` open · `[~]` in progress · `[x]` done. Newest-relevant on top.

---

## Desktop / aesthetic

- [x] **Default media player (MIME) — fix + restyle** — done 2026-05-30.
  1. MIME unified: all `audio/*` + `video/*` pinned to `mpv.desktop` in
     `~/.config/mimeapps.list` (flac/webm no longer open in Firefox; verified with
     `xdg-mime query default`).
  2. Restyled: new stowed `mpv/` module — `mpv.conf` (paper-cream window, Terminess OSD,
     palette colors) + `script-opts/osc.conf` theming the **built-in osc** (palette colors,
     scaled 0.8, `barmargin` so fullscreen doesn't clip the bottom bar).
  - uosc was tried and abandoned (don't retry blindly): it asks for its icon font by
     PostScript name `MaterialIconsRound-Regular`, but libass memory-matches fonts by
     *family* (`Material Icons Round`) → on this Nerd-Font-heavy box it fell back to Noto
     and rendered big black squares. Even a fontconfig dir+alias rewrite didn't clear it.
  - Follow-up: pull `~/.config/mimeapps.list` into the repo? It carries machine-specific
     entries (Burp handler), so left live-only for now.

- [ ] **wlsunset night light.** Installed but not running/configured. Wire it into niri
      `spawn-at-startup` with day/night temps + the local lat/long, if wanted.

## Cleanup / housekeeping

- [x] **Stop orphaned `mpd.service`** (user) — stopped 2026-05-30; nothing re-spawned it.
- [x] **Commit untracked files** into `~/celestia` (CONTEXT/CLAUDE/todos + xfce4/) — done 2026-05-30.
- [x] **Regenerate `packages.txt`** — done 2026-05-30 (113 explicit).
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
