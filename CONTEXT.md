# CONTEXT.md — laniakea · system manifest (maintenance rules: §META)

## 1. Machine identity
Verified: 2026-07-31

- Hostname `laniakea`, user `aru`, repo `~/dotfiles` (branch `laniakea`).
  ThinkPad X280 laptop; companion to celestia (PC, branch `celestia`).
- Intel 8th-gen (i5/i7 — exact model unknown), iGPU UHD 620, intel_pstate
  active. RAM 16 GB, NVMe 238 GB.
- Display eDP-1: 1920x1080, 12.5", scale=1 in niri.
- Battery BAT0 (01AV470 Cellonic, 44.46 Wh, 2026-07); TLP 85/90; EPP knob,
  no platform_profile; lid→suspend-then-hibernate, S3 pinned (`power/`).
- Wifi + Bluetooth present. Arch Linux; login shell fish; boot flow
  greetd + cage + quickshell-greeter on VT1.

## 2. Ideology
Verified: 2026-07-11

- Performance-driven minimalism: every component earns its RAM and its
  LOC; no daemon a script can replace.
- Every package must answer three questions: simpler alternative?
  removable? replaceable by something already present?
- CLI-first, keyboard-driven (hjkl everywhere); GUI only where a terminal
  genuinely can't do it.
- One resident Qt process (quickshell) is the whole desktop chrome: bar,
  control center, locker, launcher; greeter is the same stack.
- Flexoki Dark invariants: squared corners (never rounded), no blur,
  Terminess Nerd Font Mono (Unifont for bitmap-crisp bar/CJK); kitty italic
  = the custom Terminus Italic (`terminus-italic/`); GTK widgets stock
  Adwaita dark + Flexoki named-color overrides. Palette source of truth:
  PALETTE.md — never invent hex values.
- No decorative Unicode glyphs in QML — bitmap fonts render them unevenly;
  pixel primitives (Rectangles) instead. Don't iterate palette or fonts
  without explicit direction from Ars.
- Root-owned `/etc` configs are never symlinked: module `install.sh`
  (backup, validate, reload) is the source of truth. User configs deploy
  via stow; packages with non-config top-level files carry
  `.stow-local-ignore`.
- Repo is the single source: edit here, deploy out; never hand-edit
  deployed copies. Trim before adding; this file obeys its budgets (§META).

## 3. Stack map
Verified: 2026-08-22

Stow modules (from `~/dotfiles`, target under `~/.config`):
- niri/ — Wayland compositor. Spawns qs, swaybg, swayidle, mako.
- quickshell/ — bar + control center + locker + launcher, plus battery
  widget, EPP power cycler, wifi/BT/airplane rows; polkit rules + set-epp
  (dir symlink; rules/set-epp = manual sudo install to
  /etc/polkit-1/rules.d, /usr/local/bin).
- swayidle/ — idle pipeline: 5m dim → 10m lock+screen-off → 30m suspend;
  lock before sleep; lid handling.
- fish/ (login shell; default/emacs binds not vi; zoxide `cd`), kitty/
  (Terminess 12pt; super+c/v copy-paste), tmux/ (256-idx statusline, TPM,
  sesh popup on M-Space; Alt tier forwarded into nvim via is_vim), nvim/
  (native treesitter, flexoki lualine, fzf-lua, session start-screen,
  Space leader), mako/
  (Quiet/DND wired to CC), xdg/ (mimeapps.list), gtk/ (+ apply.sh,
  icons-install.sh), fontconfig/ (Terminus alias; Terminess AA-off on
  native px only), yazi/, fastfetch/, zathura/, mpv/.

install.sh modules (root-owned or per-profile targets, not stowable):
- quickshell-greeter/ → /etc/quickshell-greeter + /etc/greetd/config.toml
  (mirrors the lock state-machine).
- keyd/ → /etc/keyd (CapsLock tap→Ctrl; Shift+CapsLock→real CapsLock;
  corner Ctrl→Menu, which xkb turns into the layout switch — grp:menu_toggle
  in niri/); hid_apple/ → /etc/modprobe.d (external kbd F1-F12, fnmode=2).
- udev/ → /etc/udev/rules.d — hidraw uaccess for the Keychron (VID 3434) so
  VIA/QMK tools reach it without root. Rule file only, deployed by hand.
- nftables/, sysctl/, sshd/ → their /etc paths (see §4); firefox/ (user.js
  → random-hash *.default-release profile); obsidian/ (official Flexoki
  theme + vimrc/hotkeys → per-vault .obsidian/); crossgrub/ (GRUB theme +
  Terminess .pf2 fonts); tlp/ → /etc/tlp.d/00-aru.conf (thresholds 85/90).
- power/ → /etc/systemd/{logind,sleep}.conf.d (lid→`sleep`, 30m
  suspend-then-hibernate, `MemorySleepMode=deep`; install gated on hibernate
  being viable). tlp/ owns charging, power/ owns sleep depth.
- terminus-italic/ → ~/.local/share/fonts (custom Terminus Italic for kitty;
  install.sh ships prebuilt TTFs, build.sh regenerates via fontforge).


Not deployed / manual: wallpapers/ (Flexoki duotone sources +
`mntvagaflexoki.png` current → ~/Pictures/wallpapers), docs/ (specs,
screenshots, keybinds.md = cross-machine bind scheme + cheatsheet/vscode),
bin/ (user scripts incl. pd-bt → ~/.local/bin), telegram/
(Telegram Desktop theme — imported via the app, not stowed).

### Packages
Authoritative: packages.txt — names only (regenerate: `pacman -Qqe`);
drift check in §META. Must be generated on the laptop itself. Non-obvious
keepers: passim (masked, fwupd hard dep), swaylock (manual fallback lock),
cage (`--asexplicit`, greeter runs on it), smartmontools (battery/disk
health alongside TLP), tree-sitter-cli (nvim-treesitter main compiles parsers
via it), sesh-bin (tmux session popup on M-s), fontforge (build dep for
terminus-italic — deploy needs only the prebuilt TTFs).

## 4. Security posture — deltas from Arch defaults, each with a live check
Verified: 2026-07-11

sshd (sshd/): drop-in etc/ssh/sshd_config.d/00-hardening.conf. sshd is
first-obtained-value-wins, so `00-` sorts first and wins (install.sh
removes the old `99-` file). Effective: PasswordAuthentication no,
KbdInteractive no, PermitRootLogin no, PermitEmptyPasswords no,
X11Forwarding no. No ~/.ssh/authorized_keys → inbound SSH impossible until
`ssh-copy-id`; outbound unaffected.
Verify: `ls /etc/ssh/sshd_config.d/ && sudo sshd -T | grep -Ei 'passwordauth|kbdinteractive|permitroot|permitempty|x11forwarding'`

nftables (nftables/): single inet table; input DROP, forward DROP (laptop
— no Docker/libvirt). nft verdicts across tables are ANDed. DHCP allow
(udp 67→68; v6 547→546) must stay ABOVE `ct state invalid drop` or renewal
breaks silently. Reject is `pkttype host` + rate-limited; `iif lo accept`;
inbound-ssh/virbr0 commented; mDNS not allowed.
Verify: `sudo nft list ruleset | grep -E 'policy|counter'`

sysctl (sysctl/, 99-hardening.conf): kptr_restrict=1, yama.ptrace_scope=1,
randomize_va_space=2, rp_filter=1, ICMP redirects off (accept+send),
tcp_syncookies=1. ip_forward stays COMMENTED — no containers.
Verify: `sysctl kernel.kptr_restrict kernel.yama.ptrace_scope net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies net.ipv4.ip_forward`

passim.service masked (fwupd cache on 0.0.0.0:27500; socket-activated, no
[Install], fwupd hard dep).
Verify: `systemctl is-enabled passim.service; ss -tlnp | grep 27500`

polkit (quickshell/): scoped rules (user `aru` + exact program):
49-bluetooth-toggle (start/stop bluetooth.service from CC), 49-epp-toggle +
/usr/local/bin/set-epp (token-whitelisted EPP writes, password-less pkexec).
Verify: `ls /etc/polkit-1/rules.d/ && pkexec /usr/local/bin/set-epp balance_performance`

## 5. Machine deltas — vs celestia (PC repo)
Verified: 2026-08-22

- Bind scheme (keyd/niri/nvim/tmux/fish/kitty + docs/keybinds.md) is
  IDENTICAL by design — any change to it must land on both branches.
- Battery + tlp/ + power/ lid policy here; celestia is a desktop with none.
  quickshell extras to match: Battery widget, EPP cycler, Auto-suspend row.
- Wifi + Bluetooth here: WifiCtl/BtCtl singletons + CC rows, rfkill
  airplane toggle; celestia has no wifi/BT hardware.
- swayidle: 5m dim step is laptop-only; the CC Auto-suspend toggle here
  holds a Wayland idle inhibitor, celestia still uses systemd-inhibit —
  sync direction laniakea → celestia.
- nftables forward DROP + ip_forward commented here; celestia runs forward
  ACCEPT + ip_forward=1 (Docker).
- Greeter here is AHEAD: battery display, F1 suspend — laniakea → celestia.
- Single internal display (eDP-1); celestia is dual-monitor (sync-ws,
  per-output bars, layer-surface popups, xwayland-satellite) and AHEAD on
  the quickshell shell. crossgrub/ lives only here.

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

Drift check — run at the start of any repo work session (on the laptop):
`diff <(grep -v '^#\|^$' packages.txt | sort) <(pacman -Qqe | sort)`

Banned content: history/narration (→ git log), todos (→ Obsidian),
how-to walkthroughs (→ module READMEs), package versions.

`Verified:` stamps are per-section. A stamp older than the newest change
to a section's related files means the section is suspect.
