# celestia → Sky Paper transition — design

**Date:** 2026-05-29
**Host:** celestia (ASUS TUF B550M-PLUS, Ryzen 5 5600X, RX 6700 XT, desktop)
**Goal:** Move celestia from its current Hyprland/Chicago95 stack to laniakea's
**Sky Paper** rice (niri + Quickshell + greetd), adapting every laptop-specific
assumption to desktop values. Coexist-then-retire, fully reversible until the
final phase.

---

## 1. Source / target / canonical repo

| Tree | Role |
|------|------|
| `~/dotfiles` | celestia's **current** repo (Hyprland, waybar, tofi, mako, Chicago95). Owns the *running* configs via stow. Untouched during coexist; archived at retirement. |
| `~/laniakea` | The extracted laniakea archive (Sky Paper). **Read-only source** we adapt *from*. |
| `~/celestia` | **New canonical repo** (currently empty). Built by copying + adapting laniakea's packages for this host. Becomes `/home/segfault/celestia` after the account rename. |

Per-package layout preserved: `$HOME` configs via GNU Stow; root-owned `/etc`
bits via each package's `install.sh`.

## 2. Locked decisions

- **Shell:** adopt fish; retire the custom zsh with the old stack.
- **kitty / nvim / tmux:** adopt laniakea's (Sky Paper themed); back up celestia's current versions first.
- **nftables / sysctl:** diff-then-merge with celestia's existing hardened configs — do **not** clobber (keep Docker forward + dnscrypt allowances).
- **sshd:** stays **disabled** (installed, inactive) — status quo.
- **Username:** **rename the Linux account `admni` → `segfault`** (move `/home/admni` → `/home/segfault`). All configs/polkit target `segfault`.
- **EPP cycler:** kept (amd-pstate-epp is active); defaults to performance on a desktop.
- **tlp:** dropped (no battery; charge thresholds meaningless).
- **swayidle:** lock + monitors-off on idle; **never auto-suspend**.
- **hid_apple / keyd / crossgrub:** adopted (all apply to celestia — see §4).
- **Quickshell battery / brightness / bluetooth modules:** dropped (no hardware).

## 3. Hardware ground truth (drives config values)

| Fact | Value | Consequence |
|------|-------|-------------|
| Monitors | `DP-3` ASUS 1920x1080@165 @ `0x0` (left); `DP-2` BNQ ZOWIE 1920x1080@144 @ `1920x0` (right). DP-1/HDMI-A-1 disconnected. | niri needs **two** `output` blocks, not one `eDP-1`. |
| Keyboard | `SONIX Galaxy80`; `hid_apple` module loaded | hid_apple fnmode config **applies** here. |
| Battery | none (only `hidpp_battery_0` = wireless mouse) | Quickshell battery module has nothing to read. |
| Backlight | none (`/sys/class/backlight` empty) | brightness module dead; monitors are DDC if anything. |
| Bluetooth | none | BT toggle + polkit rule + BtCtl/BtRow dead. |
| CPU power | `amd-pstate-epp` active | EPP cycler works. |
| Boot | GRUB + EFI (`\EFI\GRUB\grubx64.efi`); `crossgrub` theme already in `/boot/grub/themes` | crossgrub applicable. |
| Keyboard layouts | celestia runs **US/RU/UA** + Alt+Shift toggle | extend laniakea's `layout "us,ru"` → `"us,ru,ua"`. |

## 4. Package-by-package disposition (24 packages)

| Package | Disposition | Adaptation |
|---|---|---|
| niri | Adapt | one `eDP-1` → two outputs (DP-3 left/165, DP-2 right/144); layout `us,ru,ua`; swaybg wallpaper path → `/home/segfault`. |
| quickshell | Adapt + rename | `aru→segfault` (LockScreen.qml, AppLauncher.qml ×3, polkit rules, set-epp). **Drop** Battery/Brightness/BtCtl/BtRow + bluetooth-toggle.rules. Keep EPP cycler (default performance). Trim ControlCenter/status rows. |
| quickshell-greeter + greetd | Adapt | replaces `ly`; register **both** `niri.desktop` + `hyprland.desktop`. `aru→segfault` in install.sh + Theme.qml. |
| swayidle | Adapt | strip suspend; keep lock + DPMS-off. |
| tlp | **Drop** | no battery. |
| hid_apple | **Adopt** | Galaxy80 present; confirm fnmode value. |
| keyd | Adopt | CapsLock→leader, keyboard-agnostic. |
| crossgrub | Adopt/verify | GRUB+EFI; confirm vs current GRUB entry. |
| nftables | Reconcile (merge) | merge with celestia's `/etc/nftables.conf`. |
| sysctl | Reconcile (merge) | merge with celestia's `99-hardening.conf`. |
| sshd | Adopt config, keep disabled | key-only config present but service off. |
| fontconfig | Adopt + rename | `aru→segfault` in obsidian.desktop `FONTCONFIG_FILE`. |
| kitty / nvim / tmux | Adopt (shared) | overwrite celestia's; back up first. Shared by both sessions. |
| fish | Adopt | new default shell. |
| gtk | Adopt (global) | Sky Paper GTK theme; restyles Hyprland GTK apps too during coexist (acceptable). |
| mako / yazi / zathura / fastfetch / obsidian / firefox / wallpapers / PALETTE | Adopt | Sky Paper theming, no hw assumptions; mako/yazi overwrite celestia's. |

## 5. Rename surfaces

**`aru → segfault`** (also `/home/aru → /home/segfault`): niri config (swaybg),
quickshell LockScreen.qml + AppLauncher.qml (×3 frecency paths), `bluetooth-toggle.rules`
(dropped anyway), `epp-toggle.rules` (`subject.user == "segfault"`), `set-epp`,
quickshell-greeter install.sh (wallpaper) + Theme.qml/BigClock.qml comments,
fontconfig obsidian.desktop, tlp (dropped).

**`laniakea → celestia`** (host references): README, swayidle config/README,
obsidian/vimrc, zathura/yazi/tlp install.sh banners, greeter LoginBox.qml,
LockBox.qml.

## 6. Security merge (nftables + sysctl)

celestia already runs hardened versions of both. Procedure: produce a side-by-side
diff of laniakea's vs celestia's, adopt the stricter rule per setting, and
**preserve celestia-specific allowances** — Docker forward policy + iptables-nft
integration, dnscrypt-proxy on 127.0.0.1:53, `ip_forward=1`. Output a single
merged file per service; user reviews the diff before it's written.

## 7. Coexist mechanism

greetd reads `/usr/share/wayland-sessions/*.desktop`. Ship **both** a
`niri.desktop` and a `hyprland.desktop` so the quickshell-greeter offers a choice.
Default to niri; Hyprland is one pick away. Switch the display manager ly→greetd
but **leave ly installed** (disabled) as a safety net until retirement.

## 8. Phased rollout

- **Phase 0 — Clean baseline.** ✓ Done (orphans removed, pacnew resolved, cache 8.2→5.8 G).
- **Phase 1 — Install, remove nothing.** niri, quickshell, greetd, fish, zathura, keyd, swayidle, crossgrub deps, fonts (Terminus/Terminess/Unifont), AUR bits. ly + Hyprland stay intact.
- **Phase 2 — Build `~/celestia` repo.** Copy laniakea packages, apply rename surfaces, niri dual-output + layouts, drop laptop modules, prepare merged nftables/sysctl. File editing only — nothing deployed.
- **Phase 3 — Account rename `admni→segfault`.** From a root TTY, graphical session closed: `usermod -l`, move home, `groupmod`, fix ownership. Re-login as segfault; repo now at `/home/segfault/celestia`.
- **Phase 4 — Deploy.** Back up + un-stow celestia's shared configs (kitty/nvim/tmux/mako/yazi/gtk); stow celestia repo. Run each `install.sh` (greetd, nftables, sysctl merged, keyd, hid_apple, fontconfig, crossgrub, sshd-disabled). Switch ly→greetd with both sessions registered.
- **Phase 5 — Live on niri, validate.** Soak several days; Hyprland session available as fallback.
- **Phase 6 — Retire (separate session, explicit go-ahead).** Remove Hyprland/waybar/tofi/hyprpaper/hyprsunset/ly/Chicago95 + `hyprland.desktop`; prune orphans; archive `~/dotfiles`; rewrite CONTEXT.md for the new stack.

Each phase reversible until Phase 6.

## 9. Risks & rollback

- **niri on AMD/dual-monitor untested** → Hyprland session kept selectable through Phase 5.
- **Account rename while logged in is impossible** → Phase 3 mandates root TTY; if it fails, admni is unchanged.
- **Security merge regressions** (lose Docker/dnscrypt) → user reviews merged diff before write; old configs backed up.
- **Shared-config overwrite** (kitty/nvim/tmux/mako/yazi/gtk) → back up before un-stow; restorable from `~/dotfiles`.

## 10. Non-goals / deferred

- BitLocker `/dev/sda` setup, swap activation — out of scope.
- mpd setup — separate task.
- Fingerprint — abandoned on laniakea, nothing to port.
- CONTEXT.md rewrite — Phase 6 only.

## 11. Open items to confirm during planning

- Exact `hid_apple` fnmode value vs desired F-key behavior.
- Whether crossgrub replaces or coexists with celestia's current GRUB entry.
- niri `spawn-at-startup` list: which laptop-only spawns to drop.
- Quickshell bar module list after dropping battery/brightness/BT — what fills the gap.
