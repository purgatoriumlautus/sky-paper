# CONTEXT.md — celestia · system manifest (maintenance rules: §META)

## 1. Machine identity
Verified: 2026-07-11

- Hostname `celestia`, user `segfault`, repo `~/celestia`. Primary PC.
- Ryzen 5 5600X (6c/12t), 16GB DDR4, RX 6700 XT (amdgpu). Ethernet-only
  (enp5s0, DHCP — never hardcode the IP); no wifi/BT hardware.
- Monitors: DP-3 ASUS VG259QR 1080p@165 (left, ws1), DP-2 BenQ ZOWIE XL
  1080p@144 (right, ws2).
- Keyboard: Epomaker X80 — reports Apple VID (05AC:024F) so `hid_apple`
  claims it; tamed by fnmode=2 + keyd CapsLock→F19 (see stack map).
- Caveats: swap partition (sdb2, 4G) exists, inactive; sda2 931G BitLocker
  drive, purpose TBD; bun at `~/.bun`, off PATH; wlsunset unwired.

## 2. Ideology
Verified: 2026-07-11

- Performance-driven minimalism: instant feel, minimal footprint, Unix
  one tool, one job.
- Every package must answer three questions: simpler alternative?
  removable? replaceable by something already present?
- Flexoki Dark invariants: squared corners (never rounded), no blur, smooth
  palette-matched animation, Terminess font throughout (kitty italic = the
  custom Terminus Italic, `terminus-italic/`).
- Chicago95 cursor + icons as a deliberate retro accent; GTK widgets
  stock Adwaita dark + Flexoki named-color overrides. Palette source of
  truth: PALETTE.md.
- Wayland-only by choice: simpler architecture, isolation by default.
- Honest scope: beyond the compositor layer this is a working desktop
  (VMs, office, media). Minimalism governs the DE layer, not the app set.

## 3. Stack map
Verified: 2026-08-21

Stow modules (from `~/celestia`, target under `~/.config`):
- niri/ — compositor. Spawns qs, xwayland-satellite, swaybg, swayidle,
  mako. niri never starts Xwayland itself; xwayland-satellite's `:0` arg
  must match the exported `DISPLAY :0` or X11 apps fail to open a display.
- quickshell/ — bar per monitor + ControlCenter/Launcher/LockScreen;
  IPC: `qs ipc call lock|launcher|controlcenter ...`.
- swayidle/ — 10 min → lock + monitors off, 30 min → suspend (CC
  "Auto-suspend" toggle blocks it); lock before sleep. No dim (no backlight).
- fish/ (login shell), kitty/ (auto-attaches tmux `main`), tmux/, nvim/
  (leader = F19 from keyd), mako/, xdg/ (mimeapps.list →
  ~/.config/mimeapps.list — new), gtk/, fontconfig/, yazi/, fastfetch/,
  zathura/, mpv/, xfce4/ (Thunar settings; deletion candidate).

install.sh modules (root-owned or per-profile targets, not stowable):
- quickshell-greeter/ → /etc/quickshell-greeter + /etc/greetd. greetd
  runs `cage -s -m last`: `-m last` pins one output (default `-m extend`
  spans both monitors, splitting the greeter across the seam). Rescue:
  root TTY → `systemctl disable --now greetd`, start niri by hand.
- keyd/ → /etc/keyd/default.conf. CapsLock tap→F19 (Shift+CapsLock→real
  CapsLock). F19 = the only F13–F24 key with a clean keysym in the
  default us map; the rest die in terminals before reaching nvim.
- hid_apple/ → /etc/modprobe.d (fnmode=2; read at module load — script
  pokes live sysfs too); nftables/, sysctl/, sshd/ → their /etc paths
  (see §4); firefox/ (user.js → random-hash profile dir); obsidian/
  (official Flexoki theme + vimrc → vault); crossgrub/ (GRUB theme);
  terminus-italic/ → ~/.local/share/fonts (custom Terminus Italic for kitty;
  install.sh ships prebuilt TTFs, build.sh regenerates via fontforge).
- restic/ → /etc/systemd/system. Weekly `/` snapshot, forget 8w+12m, via
  restic's own sftp backend (ssh alias in /root/.ssh/config, not rclone).
  /root/.restic-pass untracked — lose it and the repo is unrecoverable.
- udev/ → /etc/udev/rules.d. hidraw access for the Keychron (VID 3434)
  via TAG+="uaccess", so VIA/QMK config tools reach it without root.
  Rule file only — no install.sh, deployed by hand.
- rclone/ → /etc/systemd/system. Same Storage Box, own creds (rclone.conf,
  untracked): ~/archive mount + ~/cloud bisync every 15 min. System units
  with User=segfault, so `%h` is /root — all home paths hardcoded.

Not deployed: wallpapers/ (sources), docs/ (specs, screenshots), bin/
(user scripts incl. pd-bt — new), telegram/ (Telegram Desktop theme —
imported via the app, not stowed).

### Packages
Authoritative: packages.txt — names only (regenerate: `pacman -Qqe`);
drift check in §META. Non-obvious keepers: xwayland-satellite (X11 apps
under niri), dnsmasq (libvirt dep), iptables (Docker dep), terminus-font
vs ttf-terminus-nerd (de-dup pending), postgresql + tealdeer (newly
legitimized; three-questions review pending), fontforge (build dep for
terminus-italic — deploy needs only the prebuilt TTFs).

## 4. Security posture — deltas from Arch defaults, each with a live check
Verified: 2026-07-11

nftables (nftables/): input drop (allow established/related, lo, ICMP;
rate-limited reject); forward ACCEPT; output accept.
- Forward is accept because Docker manages forward rules via
  iptables-nft, and nft verdicts across tables are ANDed — a drop here
  would veto Docker's accepts.
- Service is plain oneshot: loads rules then reports inactive — normal.
- Verify: `sudo nft list ruleset | grep policy`; `systemctl is-enabled nftables`

sysctl (sysctl/, 99-hardening.conf): kptr_restrict=1, yama.ptrace_scope=1,
randomize_va_space=2, ip_forward=1 (Docker), rp_filter=1, ICMP redirects
off (accept+send), tcp_syncookies=1.
Verify: `sysctl kernel.kptr_restrict kernel.yama.ptrace_scope net.ipv4.ip_forward`

sshd: installed, disabled + inactive. Drop-in staged at
sshd/etc/ssh/sshd_config.d/00-hardening.conf — sshd config is
first-obtained-value-wins, so `00-` sorts first and wins.
Verify: `systemctl is-enabled sshd` → disabled

DNS: dnscrypt-proxy on 127.0.0.1 (DoH + blocklist; blocklist needs
periodic regeneration). Verify: `cat /etc/resolv.conf`

firefox: user.js forces window.open popups into tabs (niri tiles popups
as half-screen siblings — shared app_id, late title). Deploy: firefox/install.sh.

faillock: active via /etc/pam.d/system-auth. Verify: `faillock`

## 5. Machine deltas — vs laniakea (ThinkPad X280 repo)
Verified: 2026-08-03 (both sides, diffed against origin/laniakea)

- Docker + libvirt here → ip_forward=1 and nftables forward-accept;
  laniakea has neither (ip_forward commented out, forward drop).
- No battery/tlp modules here (desktop); laniakea carries them.
- Greeter: synced from laniakea (reveal on summon-key RELEASE, F2/F5 power
  keys, XKB_DEFAULT_LAYOUT=us). Not taken: battery widget, F1 suspend.
- Shell/niri: celestia is AHEAD (multi-monitor bars, layer-surface popups,
  sync-ws); sync direction celestia → laniakea.
- PC-only: hid_apple, dual-monitor niri config, xwayland-satellite.

## §META — maintenance rules
Verified: 2026-07-11

Root whitelist — module dirs plus exactly: README.md, CLAUDE.md,
CONTEXT.md, PALETTE.md, packages.txt, .gitignore, bin/, docs/. Anything
else at root is a violation: into a module, into docs/, or deleted.

Budgets (trim-don't-grow; breach = cut before commit, never raise):
identity 12 · ideology 12 · stack ~1/module · security 30 · deltas 15 ·
§META 25.

Update triggers: module change → same-commit stack-map line update;
package install/remove → packages.txt in the same sitting.

Drift check — run at the start of any repo work session:
`diff <(grep -v '^#\|^$' packages.txt | sort) <(pacman -Qqe | sort)`

Banned content: history/narration (→ git log), todos (→ Obsidian),
how-to walkthroughs (→ module READMEs), package versions.

`Verified:` stamps are per-section. A stamp older than the newest change
to a section's related files means the section is suspect.
