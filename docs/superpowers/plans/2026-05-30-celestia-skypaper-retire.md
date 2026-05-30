# celestia Sky Paper — Retire: ly → greetd, drop the old stack

**Goal:** Replace ly with greetd + the Quickshell greeter (niri-only), then remove the
Hyprland/Chicago95 stack so the box is Sky Paper end-to-end. Done in two phases so a
broken greetd never leaves you without a login: **ly stays installed (disabled) as the
rescue** until greetd is proven across a reboot.

**Preconditions (verified 2026-05-30):** niri soaked + committed (`9a17efe`); login shell
already `fish`; `niri-session` at `/usr/sbin`; `greeter` user in `video`; greetd 0.10.3
installed; greeter QML + `install.sh` + `etc/greetd/config.toml` ready in
`~/celestia/quickshell-greeter/`. Gap: **`cage` not installed** (the greeter runs inside it).

**Design note:** the Quickshell greeter hardcodes `Greetd.launch(["niri-session"])`
(`LoginBox.qml:96`), so greetd offers **no session picker** — switching to it is itself the
removal of the Hyprland login path. That's intended; Phase R2 just cleans up what's no
longer reachable.

---

## ⛑ RESCUE CARD — if a boot lands on a blank/looping screen

You are not locked out. ly is still installed.

1. `Ctrl+Alt+F2` (or F3) → log in as **root** (or `segfault` then `su -`).
2. Put ly back:
   ```
   systemctl disable --now greetd
   systemctl enable --now ly@tty2
   ```
3. `reboot`. You're back on the ly login picker.
4. Read the greeter log to see why greetd failed:
   `cat /var/cache/quickshell-greeter/qs.log` (if present) and `journalctl -b -u greetd`.

To roll the greetd *config* back to the pre-switch default:
`cp /etc/greetd/config.toml.bak /etc/greetd/config.toml` (install.sh made the .bak).

---

## Phase R1 — ly → greetd

### R1.1 Install cage  (sudo — HUMAN)
```
! sudo pacman -S --needed cage
```
`cage` is the kiosk compositor that hosts the greeter (config command is
`cage -s -- env QT_QPA_PLATFORM=wayland … qs -p /etc/quickshell-greeter`).

### R1.2 Deploy the greeter  (sudo — HUMAN)
```
! sudo bash ~/celestia/quickshell-greeter/install.sh
```
Installs QML → `/etc/quickshell-greeter/`, wallpaper → `/etc/quickshell-greeter/wallpaper.png`,
state dir `/var/cache/quickshell-greeter` (owned greeter:greeter), and
`/etc/greetd/config.toml` (backing up the existing one to `.bak`).
**Requires** `~/Pictures/wallpapers/clouds.png` to exist (it does — Task 4.4).

### R1.3 Verify deploy  (CLAUDE)
- `/etc/quickshell-greeter/` has the 7 `.qml` + `wallpaper.png`.
- `/etc/greetd/config.toml` matches the repo (cage command, `user = "greeter"`).
- `/var/cache/quickshell-greeter` owned `greeter:greeter`.

### R1.4 Preview smoke-test  (CLAUDE — non-destructive)
Run the greeter QML inside the *current* niri session, no DM change:
`qs -p /etc/quickshell-greeter` as segfault. `Greetd.available` is false → preview mode
(LoginBox shows "greetd unavailable (preview)", Esc quits). This catches QML/import errors
before we ever touch the display manager. Fix any load error, re-run, then stop.

### R1.5 Cutover  (sudo — HUMAN)
```
! sudo systemctl disable ly@tty2
! sudo systemctl enable greetd
```
Do **not** `pacman -R ly` here — it's the rescue. Then **reboot**.

### R1.6 Confirm  (HUMAN reports)
At the greeter: type password, Enter → niri comes up on both monitors. Remembered-user
file means it's just `[password] Enter` next time. Bars/wallpaper/layouts as before.
**If it fails → RESCUE CARD above.** Only once a clean greetd boot is confirmed do we
proceed to R2.

---

## Phase R2 — drop the old stack  (only after R1.6 confirmed)

**Un-stow from `~/dotfiles`** (still linked into `~/.config`): `hypr mpd swappy tofi waybar
xfce4`, and `~/.zshrc`. `cd ~/dotfiles && stow -D <pkg…>`; verify the symlinks are gone.

**Remove packages** — in tiers, each verified first (don't yank a niri dep):
- **Safe (Hyprland-only):** `hyprland hyprpaper hyprsunset xdg-desktop-portal-hyprland
  waybar tofi`. Confirm `xdg-desktop-portal-gtk` stays (niri's portal).
- **ly:** remove only after greetd has booted cleanly at least once.
- **Chicago95:** `chicago95-gtk-theme-git`, `chicago95-icon-theme-git` may go IF the niri/gtk
  configs don't reference the Chicago95 GTK/icon theme. **`xcursor-chicago95-git` STAYS** —
  Sky Paper keeps the Chicago95 cursor. Grep the gtk config + niri `cursor`/`environment`
  before removing anything theme-related.
- **zsh:** remove after a fish soak (shell already fish; `~/.zshrc` un-stowed above). Keep
  if you want a fallback shell — ask.
- **mpd/mpc/rmpc:** music stack, orthogonal to the rice — **ask the user**, don't assume.

**Repos:** archive `~/dotfiles` (rename/tag, don't `rm`) once nothing links into it; leave
`~/laniakea` (reference archive). `~/celestia` is canonical.

**Docs:** rewrite `~/dotfiles/CONTEXT.md` → Sky Paper reality (or move the canonical
CONTEXT into `~/celestia`), and bump CONTEXT "Last verified".

**Orphans sweep:** `pacman -Qtdq` after removals; review before `pacman -Rns`.
