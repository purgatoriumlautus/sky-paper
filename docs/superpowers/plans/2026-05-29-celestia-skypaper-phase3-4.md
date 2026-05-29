# celestia Sky Paper — Phase 3+4: account rename + deploy

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Steps use `- [ ]`.
> Companion: `~/celestia/HANDOFF.txt` — the subset of steps the human runs (root TTY, reboots, sudo, greeter picks). Claude does everything else.

**Goal:** Rename the Linux account `admni → segfault`, then deploy the adapted `~/celestia` repo so niri/Quickshell becomes a selectable session — while keeping the Hyprland/Chicago95 stack fully working as a fallback.

**Architecture:** Phase 3 is an irreversible account rename done by the human at a root TTY (Claude cannot reach a TTY or type root/sudo passwords). Phase 4 deploys user configs via stow + root `install.sh` scripts. **The display manager stays `ly`** for the coexist soak — ly's login screen lets you arrow-pick `niri` or `hyprland`. greetd + the Quickshell greeter (which hardcodes `niri-session`) are deferred to a later "retire" plan, after niri is trusted.

**Tech stack:** usermod, GNU Stow, niri, Quickshell, fish, wlsunset, polkit, ly.

**Design note (changed from the spec):** the spec assumed greetd would offer both niri and Hyprland sessions. It can't — `LoginBox.qml:96` hardcodes `Greetd.launch(["niri-session"])`. So coexist uses **ly** (already installed) as the session picker during the soak; the greetd switch moves to the retire plan.

**Preconditions:** Phase 1+2 done (packages installed, `~/celestia` built, nothing deployed). Logged in as `admni`. `~/celestia`, `~/dotfiles`, `~/laniakea` all under `/home/admni` (they move with the home dir during the rename).

---

## Phase 3 — Account rename `admni → segfault`  (HUMAN, at a root TTY)

**Facts:** `admni` = uid 1000, private group `admni` (gid 1000), member of `wheel docker libvirt libvirt-qemu vboxusers`. Only human account on the box (no fallback admin). sudo is granted via `%wheel` (group survives the rename); confirm no file names `admni` explicitly.

### Task 3.1: Pre-flight (run as admni, BEFORE going to the TTY)

- [ ] **Step 1: Confirm you can become root** (the rename is done as root; if root login fails you'd need a live USB).
```bash
su -            # enter root password; if it works, type `exit`. If it FAILS, STOP.
```
- [ ] **Step 2: Check for explicit `admni` references root will need to fix later.**
```bash
sudo grep -rn 'admni' /etc/sudoers /etc/sudoers.d/ /etc/subuid /etc/subgid 2>/dev/null
```
Expect: at most `subuid`/`subgid` lines (rootless-container maps) and NO explicit `admni ALL=` in sudoers (you rely on `%wheel`). Note anything that appears — you'll fix it in Task 3.2 step 7.
- [ ] **Step 3: Make sure git is clean in all three repos** (so nothing is lost in the move).
```bash
for r in ~/celestia ~/dotfiles ~/laniakea; do echo "== $r =="; git -C "$r" status -s; done
```
Commit/stash anything you care about.

### Task 3.2: The rename (run as ROOT at a TTY, with admni's GUI session ended)

- [ ] **Step 1:** Switch to a text console: `Ctrl+Alt+F3`. Log in as **root**.
- [ ] **Step 2: End admni's session** so no processes hold the home dir open.
```bash
loginctl terminate-user admni
pgrep -u admni && echo "STILL RUNNING — wait / repeat" || echo "admni has no processes ✓"
```
- [ ] **Step 3: Rename the login name.**
```bash
usermod -l segfault admni
```
- [ ] **Step 4: Move the home directory** (this physically moves `/home/admni` → `/home/segfault`; may take a moment).
```bash
usermod -d /home/segfault -m segfault
```
- [ ] **Step 5: Rename the private group** (keeps `id` tidy; gid stays 1000).
```bash
groupmod -n segfault admni
```
- [ ] **Step 6: Verify.**
```bash
id segfault            # uid=1000(segfault) gid=1000(segfault) groups=...wheel...docker...
ls -ld /home/segfault  # owned by segfault, exists
ls /home               # no 'admni' left
```
- [ ] **Step 7: Fix any stragglers** found in 3.1 step 2 (edit by hand as root):
```bash
grep -rn 'admni' /etc 2>/dev/null   # subuid/subgid/sudoers.d → change admni → segfault
```
- [ ] **Step 8: Reboot.** `reboot`
- [ ] **Step 9: At the ly login, log in as `segfault`.** Confirm:
```bash
whoami            # segfault
echo $HOME        # /home/segfault
ls ~/celestia ~/dotfiles ~/laniakea   # all present at the new path
```

**Rollback:** if anything looks wrong before step 8, the rename is reversible at the root TTY (`usermod -l admni segfault; usermod -d /home/admni -m admni; groupmod -n admni segfault`).

---

## Phase 4 — Deploy as segfault  (CLAUDE does the work; sudo + reboots = HUMAN)

> From here Claude runs the non-root steps directly. Each `sudo` step is handed to you to run via `! …`.

### Task 4.1: Install the niri-session runtime deps

- [ ] **Step 1 (sudo — HUMAN):** niri's "Warm" toggle uses `wlsunset`; it's not installed yet. (`cage` is intentionally NOT installed — only needed for greetd, which we defer.)
```bash
sudo pacman -S --needed wlsunset
```
- [ ] **Step 2 (Claude): verify the rest of the niri session's deps are already present:** `niri swaybg swayidle mako qs fish` (all from Phase 1), `xdg-desktop-portal-gtk` (present). Report any gap.

### Task 4.2: Back up + un-stow the SHARED configs from the old repo

The old `~/dotfiles` currently symlinks these into `~/.config`: `kitty nvim tmux mako gtk-{2,3,4}.0`. They must come out before celestia's versions go in. **Keep** `hypr waybar tofi swappy xfce4 mpd` stowed (Hyprland fallback) and `~/.zshrc` (until fish soak).

- [ ] **Step 1 (Claude): back up the live targets**, then un-stow only the shared packages.
```bash
mkdir -p ~/config-backup-pre-skypaper
cp -rL ~/.config/{kitty,nvim,tmux,mako} ~/config-backup-pre-skypaper/ 2>/dev/null
cd ~/dotfiles && stow -D kitty nvim tmux mako gtk
```
- [ ] **Step 2 (Claude): confirm those symlinks are gone, fallback ones remain.**
```bash
for d in kitty nvim tmux mako gtk-3.0; do test -e ~/.config/$d && echo "$d still present" || echo "$d removed ✓"; done
test -L ~/.config/hypr && echo "hypr still stowed ✓ (fallback intact)"
```

### Task 4.3: Stow celestia's user configs

- [ ] **Step 1 (Claude):** stow the Sky Paper user packages from `~/celestia`.
```bash
cd ~/celestia && stow niri quickshell quickshell-greeter kitty nvim tmux fish mako yazi zathura fontconfig gtk fastfetch swayidle
```
- [ ] **Step 2 (Claude): verify symlinks resolve into ~/celestia.**
```bash
for d in niri quickshell kitty nvim fish; do echo "$d -> $(readlink ~/.config/$d)"; done
```
Expected: each points at `../celestia/<pkg>/.config/<pkg>`.

### Task 4.4: Wallpaper + state dirs

- [ ] **Step 1 (Claude):** niri's `swaybg` and the lock/greeter expect `~/Pictures/wallpapers/clouds.png`.
```bash
mkdir -p ~/Pictures/wallpapers && cp ~/celestia/wallpapers/clouds.png ~/Pictures/wallpapers/clouds.png
mkdir -p ~/.local/state/quickshell   # AppLauncher frecency json lives here
```

### Task 4.5: Root-owned `/etc` bits via install.sh  (each is sudo — HUMAN runs)

All scripts were already path-patched (`aru→segfault`, `~/dotfiles→~/celestia`) in Phase 2.

- [ ] **Step 1 — keyd** (CapsLock→leader): `! sudo bash ~/celestia/keyd/install.sh` then `! sudo systemctl enable --now keyd`
- [ ] **Step 2 — hid_apple** (fnmode=2, F-keys primary on the Galaxy80): `! sudo bash ~/celestia/hid_apple/install.sh`
- [ ] **Step 3 — fontconfig** (bitmap font rules): `! sudo bash ~/celestia/fontconfig/install.sh`
- [ ] **Step 4 — zathura, yazi** (mime + preview deps): `! sudo bash ~/celestia/zathura/install.sh` ; `! sudo bash ~/celestia/yazi/install.sh`
- [ ] **Step 5 — EPP password-less toggle** (for the CC Power-profile row):
```bash
! sudo install -m 0755 ~/.config/quickshell/set-epp /usr/local/bin/set-epp
! sudo install -m 0644 ~/.config/quickshell/epp-toggle.rules /etc/polkit-1/rules.d/49-epp-toggle.rules
```
- [ ] **Step 6 — sshd** (installs key-only hardening config but leaves the service OFF, per decision):
```bash
! sudo bash ~/celestia/sshd/install.sh
systemctl is-enabled sshd   # expect: disabled
```
- [ ] **Step 7 — nftables + sysctl** (the merged, already-reviewed files). Validate, then deploy + reload:
```bash
! sudo bash ~/celestia/nftables/install.sh && sudo nft -c -f /etc/nftables.conf && sudo systemctl reload nftables
! sudo bash ~/celestia/sysctl/install.sh && sudo sysctl --system | tail -3
```
- [ ] **Step 8 — crossgrub (REVIEW FIRST, optional):** celestia already has a `crossgrub` theme dir in `/boot/grub/themes`. Before running, Claude diffs the repo's GRUB theme/`/etc/default/grub` change against the current boot setup; deploy only if it doesn't break your existing entry. `! sudo bash ~/celestia/crossgrub/install.sh` **only after review.**

### Task 4.6: Trim the greeter's battery readout (Claude)

`quickshell-greeter/.config/quickshell-greeter/Greeter.qml` reads `/sys/class/power_supply/BAT0` (mirrors the LockScreen readout already removed). Remove that Row so the greeter doesn't show a stuck `0%` when greetd lands later. Commit.

### Task 4.7: fish as login shell

- [ ] **Step 1 (sudo/password — HUMAN):** `! chsh -s /usr/bin/fish`
- [ ] **Step 2:** Next login uses fish. (zsh stays installed; `~/.zshrc` still stowed until you're happy.)

### Task 4.8: First niri boot + validation

- [ ] **Step 1 (HUMAN): reboot**, and at the **ly login screen cycle the session to `niri`** (←/→ arrows or F-key) and log in.
- [ ] **Step 2 (validate, together):**
  - Quickshell bar appears on both DP-3 and DP-2; clock + λ control-center icon present.
  - `Mod+Space` opens the control center; J/K wraps the **6** rows (Volume/Warm/Auto-suspend/Quiet/Output/Power-profile); no Brightness/Wifi/BT rows.
  - Both monitors active, correct left/right placement; `niri msg outputs` matches.
  - Alt+Shift cycles us → ru → ua.
  - Wallpaper shows on both outputs.
- [ ] **Step 3 (fallback proof):** log out, at ly pick **`hyprland`**, confirm the old desktop still works untouched.

### Task 4.9: Soak

Run niri for a few days. Anything broken → log out → pick `hyprland` at ly. When niri is trusted, we move to the retire plan (greetd + Quickshell greeter switch, drop Hyprland/waybar/tofi/Chicago95/ly, rewrite CONTEXT.md).

---

## Self-review

**Coverage:** rename → 3.x ✓; deps (wlsunset) → 4.1 ✓; un-stow/stow → 4.2/4.3 ✓; wallpaper/state → 4.4 ✓; keyd/hid_apple/fontconfig/zathura/yazi/EPP/sshd/nftables/sysctl/crossgrub → 4.5 ✓; greeter battery trim → 4.6 ✓; fish chsh → 4.7 ✓; niri boot + fallback → 4.8 ✓. Deferred by design: greetd switch, cage, Hyprland retirement → retire plan.

**Human-only steps (go in HANDOFF.txt):** 3.1 su test, all of 3.2 (root TTY rename), every `sudo`/`!` in 4.1 & 4.5 & 4.7, and the reboots/session-picks in 4.8.

**Risks:** rename is the only irreversible-ish step — mitigated by root-login pre-check + reversible commands + no deploy until logged in as segfault. Deploy is reversible (re-stow old dotfiles; nftables/sysctl reload from old files). Hyprland stays selectable at ly throughout.

**Open items resolved this round:** hid_apple fnmode=2 (correct), niri spawns all desktop-valid (nothing dropped), wlsunset is the Warm backend (added to deps). Still pending review: crossgrub vs current GRUB (4.5 step 8, gated).
