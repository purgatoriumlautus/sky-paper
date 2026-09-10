 CONTEXT.md — laniakea · system manifest (maintenance rules: §META)

## 1. Machine identity
Verified: 2026-08-23

- Hostname `laniakea`, user `aru`, repo `~/dotfiles` (branch `laniakea`).
  ThinkPad X280 (20KE); companion to celestia (PC, branch `celestia`).
- Intel i5-8350U (Kaby Lake-R, 4c/8t), iGPU UHD 620, intel_pstate active.
- RAM 16 GB; NVMe 238 GB = 1G /boot, 16G swap, 221G ext4 `/`. Swap ≥ RAM,
  so hibernate is viable — power/ gates its install on exactly that.
- Display eDP-1: 1920x1080, 12.5", scale=1 in niri.
- Battery BAT0 (01AV470 replacement pack, 44.46 Wh design, 2026-07); TLP
  85/90; EPP knob, no platform_profile; lid→suspend-then-hibernate, S3
  pinned (`power/`).
- Intel AX210 wifi (NetworkManager, `wifi.backend=iwd`) + Bluetooth. Arch
  Linux; fish login shell; boot greetd + cage + quickshell-greeter on VT1.

## 2. Ideology
Verified: 2026-08-23

- Performance-driven minimalism: every component earns its RAM and LOC.
  Every package answers: simpler? removable? already present elsewhere?
- CLI-first, keyboard-driven (hjkl everywhere); GUI only where a terminal
  can't. quickshell is the entire desktop chrome in one Qt process — bar,
  CC, locker, launcher — and the greeter is the same stack.
- Flexoki Dark invariants: squared corners (never rounded), no blur,
  Terminess Nerd Font Mono (Unifont for bar/CJK), kitty italic = custom
  Terminus Italic, GTK stock Adwaita dark + Flexoki named colors, no
  decorative Unicode in QML (pixel Rectangles). PALETTE.md rules: never
  invent hex or re-pick fonts without Ars.
- Root-owned `/etc` is never symlinked — `install.sh` owns it, user configs
  stow. Repo is the single source: edit here, deploy out, never hand-edit.

## 3. Stack map
Verified: 2026-08-23

Stow modules (from `~/dotfiles`, target under `~/.config`):
- niri/ — Wayland compositor. Spawns qs, swaybg, swayidle, mako and
  xwayland-satellite `:0` (arg must match the exported DISPLAY).
- quickshell/ — bar + control center + locker + launcher + clipboard picker
  (CC, launcher and picker are layer surfaces; the picker reads cliphist,
  whose watcher is the wl-paste niri spawns), plus battery widget, EPP
  cycler, wifi/BT/airplane and mako-DND rows; polkit rules + set-epp (dir
  symlink; rules/set-epp = manual sudo install to /etc/polkit-1/rules.d,
  /usr/local/bin).
- swayidle/ — 5m dim → 10m lock+screen-off → 30m suspend; lock before
  sleep. Lid handling belongs to logind (power/).
- fish/ (login shell; default/emacs binds not vi; zoxide `cd`; conf.d/ +
  autoloaded functions/, config.fish is just the map), kitty/ (Terminess
  12pt; clipboard on Ctrl/Shift+Insert), tmux/ (256-idx bar, TPM,
  sesh popup on M-Space; Alt tier forwarded into nvim via is_vim), nvim/
  (native treesitter, flexoki lualine, fzf-lua, session start-screen,
  Space leader), mako/ (Quiet/DND wired to CC), xdg/ (mimeapps.list +
  yazi-kitty.desktop), gtk/ (+ apply.sh, icons-install.sh), fastfetch/,
  mpv/, yazi/ + zathura/ (config stows; their install.sh only pulls pacman
  deps and sets xdg-mime defaults). Modules whose top-level files would
  leak into $HOME carry `.stow-local-ignore`.
- fontconfig/ — NOT stowed: install.sh links conf.d/, obsidian-fonts.conf
  and the Obsidian .desktop (targets one stow tree can't share; Terminus
  alias, Terminess AA-off on native px, AA-on inside Obsidian).

install.sh modules (root-owned or per-profile targets, not stowable):
- quickshell-greeter/ → /etc/quickshell-greeter + /etc/greetd/config.toml
  (mirrors the lock state-machine; `cage -s`, XKB_DEFAULT_LAYOUT=us).
- keyd/ → /etc/keyd (CapsLock tap→Ctrl; Shift+CapsLock→real CapsLock; corner
  Ctrl→Menu = layout switch via grp:menu_toggle in niri/; [meta]/[alt] carry
  the Mac's Cmd tier; Fn→rightalt→[fnrow] rebuilds F-row media/brightness —
  docs/keybinds.md §7); hid_apple/ → /etc/modprobe.d (external kbd, fnmode=2).
- udev/ → /etc/udev/rules.d — hidraw uaccess for the Keychron (VID 3434) so
  VIA/QMK tools reach it without root. Rule file only, deployed by hand.
- nftables/, sysctl/, sshd/ → their /etc paths (see §4); firefox/ (user.js
  → random-hash *.default-release profile; vimium-keymap.txt is paste-only —
  Vimium keeps binds in extension storage; tab create/close/restore live in
  about:keybinds → customKeys.json, in-profile and untracked,
  docs/keybinds.md §9); obsidian/
  (official Flexoki theme + vimrc/hotkeys → per-vault .obsidian/);
  crossgrub/ (GRUB theme + Terminess .pf2 fonts); tlp/ →
  /etc/tlp.d/00-aru.conf (thresholds 85/90).
- power/ → /etc/systemd/{logind,sleep}.conf.d (lid→`sleep`, 30m
  suspend-then-hibernate, `MemorySleepMode=deep`; install gated on hibernate
  being viable). tlp/ owns charging, power/ owns sleep depth.
- restic/ → /etc/systemd/system + /etc/systemd/user. Weekly `/` snapshot via
  restic's own sftp backend (ssh alias in /root/.ssh/config, not rclone),
  skipped on a METERED link; a user timer notifies when the run's stamp goes
  >7d stale. /root/.restic-pass untracked — lose it, lose the repo.
- rclone/ → /etc/systemd/system. Same Storage Box, separate creds
  (rclone.conf, gitignored): ~/archive mount + ~/cloud bisync every 15 min.
- terminus-italic/ → ~/.local/share/fonts (custom Terminus Italic for kitty;
  install.sh ships prebuilt TTFs, build.sh regenerates via fontforge).
- skills/ → ~/.claude/skills (personal Claude Code skills, symlinked per
  skill so repo edits are live; `.claude/` is gitignored, hence not stow).

Not deployed / manual: wallpapers/ (Flexoki duotone sources +
`mntvagaflexoki.png` current → ~/Pictures/wallpapers), docs/ (specs,
screenshots, keybinds.md = the bind scheme and why it is that way,
keybinds-reference.md = every bind in every layer, tables only — the two are
the ONLY cheatsheets, per-module CHEATSHEET.txt and generated png/html/pdf
copies are banned, they drift; keybinds-brief.md = source brief, remote/ =
work Ubuntu box, vscode/ = Mac keymap, unused), bin/ (user scripts incl.
pd-bt → ~/.local/bin), telegram/
(Telegram Desktop theme — imported via the app, not stowed).

### Packages
Authoritative: packages.txt — names only (regenerate: `pacman -Qqe`);
drift check in §META. Must be generated on the laptop itself. Non-obvious
keepers: passim (masked, fwupd hard dep), swaylock (manual fallback lock),
cage (greeter runs on it), smartmontools (battery/disk health), imv (xdg
image handler), xwayland-satellite (X11 apps under niri), tree-sitter-cli
(nvim-treesitter main compiles parsers with it), sesh-bin (tmux popup on
M-Space), fuse3 (rclone mount), cliphist (clipboard history; its watcher is
the wl-paste niri spawns). fontforge is NOT installed — terminus-italic
deploys the prebuilt TTFs; build.sh needs it back only to regenerate them.

## 4. Security posture — deltas from Arch defaults, each with a live check
Verified: 2026-08-23

sshd (sshd/): drop-in etc/ssh/sshd_config.d/00-hardening.conf. sshd is
first-obtained-value-wins, so `00-` sorts first and wins. Effective:
PasswordAuthentication no, KbdInteractive no, PermitRootLogin no,
PermitEmptyPasswords no, X11Forwarding no. No ~/.ssh/authorized_keys →
inbound SSH impossible until `ssh-copy-id`; outbound unaffected.
Verify: `ls /etc/ssh/sshd_config.d/ && sudo sshd -T | grep -Ei 'passwordauth|kbdinteractive|permitroot|permitempty|x11forwarding'`

nftables (nftables/): ONE inet table, defined only in nftables.d/00-filter.nft
(a second file redefining it used to win by load order — removed). Input DROP,
forward ACCEPT + `iifname docker0 accept`: Docker manages forward via
iptables-nft and nft verdicts across tables are ANDed, so a drop here would
veto Docker's accepts. DHCP allow (udp 67→68; v6 547→546) must stay ABOVE
`ct state invalid drop` or renewal breaks silently. Reject is `pkttype host` +
rate-limited; `iif lo accept`; inbound-ssh/virbr0 commented; mDNS not allowed.
Verify: `sudo nft list ruleset | grep -E 'policy|counter'`

sysctl (sysctl/, 99-hardening.conf): kptr_restrict=1, yama.ptrace_scope=1,
randomize_va_space=2, rp_filter=1, ICMP redirects off (accept+send),
tcp_syncookies=1. ip_forward stays COMMENTED. docker is installed and
docker.socket enabled, but dockerd is not running: starting it inserts its
own chains and flips ip_forward at runtime — a live dockerd is a posture
change, not the steady state.
Verify: `sysctl kernel.kptr_restrict kernel.yama.ptrace_scope net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies net.ipv4.ip_forward; systemctl is-active docker`

passim.service masked (fwupd cache on 0.0.0.0:27500; socket-activated, no
[Install], fwupd hard dep).
Verify: `systemctl is-enabled passim.service; ss -tlnp | grep 27500`

polkit (quickshell/): scoped rules (user `aru` + exact program):
49-bluetooth-toggle (start/stop bluetooth.service from CC), 49-epp-toggle +
/usr/local/bin/set-epp (token-whitelisted EPP writes, password-less pkexec).
Verify: `ls /etc/polkit-1/rules.d/ && pkexec /usr/local/bin/set-epp balance_performance`

## 5. Machine deltas — vs celestia (PC repo)
Verified: 2026-09-07

- Bind scheme (keyd/niri/nvim/tmux/fish/kitty + docs/keybinds.md) is
  IDENTICAL by design — any change to it must land on both branches.
- Battery + tlp/ + power/ lid policy here; celestia is a desktop with none.
  quickshell extras to match: Battery, Brightness, EPP cycler.
- Wifi + Bluetooth here (WifiCtl/BtCtl + CC rows, rfkill airplane); celestia
  has no such hardware.
- swayidle: the 5m dim step is laptop-only (no backlight there). The
  auto-suspend Wayland idle inhibitor is now the same on both.
- nftables table identical (forward accept + docker0); ip_forward stays
  commented here, =1 on celestia.
- AHEAD here, laniakea → celestia: greeter battery + F1 suspend.
- Single display (eDP-1) vs celestia dual — sync-ws, per-output bars, shared
  CC/launcher popups. celestia AHEAD there.
- Only here: crossgrub/, power/, tlp/; only there: xfce4/, gtk bookmarks.
  restic/+rclone/ on both, METERED skip laptop-only.

## §META — maintenance rules
Verified: 2026-09-09

Root whitelist — module dirs plus exactly: README.md, CLAUDE.md,
CONTEXT.md, PALETTE.md, packages.txt, .gitignore, bin/, docs/, skills/.
Anything else at root is a violation: into a module, into docs/, or deleted.

Budgets (trim-don't-grow; breach = cut before commit, never raise):
identity 12 · ideology 12 · stack ~1/module · security 30 · deltas 15 ·
§META 25.

Update triggers: module change → same-commit stack-map line update;
package install/remove → packages.txt in the same sitting; ANY bind added,
moved or dropped → same-commit edit of docs/keybinds.md (scheme) AND
docs/keybinds-reference.md (tables). Those two are the contract, and the
only place the whole scheme is visible at once — edit them deliberately; a
config that disagrees is drift to reconcile now, not a silent new rule.

Drift check — run at the start of any repo work session (on the laptop):
`diff <(grep -v '^#\|^$' packages.txt | sort) <(pacman -Qqe | sort)`

Banned content: history/narration (→ git log), todos (→ Obsidian),
how-to walkthroughs (→ module READMEs), package versions.

`Verified:` stamps are per-section. A stamp older than the newest change
to a section's related files means the section is suspect.
