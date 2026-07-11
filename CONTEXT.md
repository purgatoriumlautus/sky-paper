# CONTEXT — laniakea

Manifest for Claude: machine facts, ideology, stack, security posture, maintenance rules (§META).
History lives in `docs/journal-2026.md` and `git log`, not here.

## Machine identity

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

- ThinkPad X280 — hostname `laniakea`, user `aru`, repo `~/dotfiles` (branch `laniakea`). Role: laptop; companion to celestia (PC, branch `celestia`).
- CPU: Intel 8th-gen (i5/i7 — exact model unknown), iGPU UHD 620, intel_pstate active.
- RAM 16 GB, NVMe 238 GB.
- Display eDP-1: 1920x1080, 12.5", scale=1 in niri.
- Battery BAT0 (01AV471), TLP charge thresholds 85/90.
- Arch Linux; login shell fish; boot flow greetd + cage + quickshell-greeter on VT1.

## Ideology

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

- Performance-driven minimalism: every component earns its RAM and its LOC.
- Three questions before any package stays: is there a simpler alternative? can it be removed outright? can something already installed do the job?
- No daemon a script can replace.
- CLI-first, keyboard-driven (hjkl everywhere); GUI only where a terminal genuinely can't do it.
- One resident Qt process (quickshell) is the whole desktop chrome: bar, control center, locker, launcher; greeter is the same stack.
- Sky Paper invariants: squared corners, no blur, Terminess Nerd Font Mono (Unifont for bitmap-crisp bar/CJK/italic), all colors from `PALETTE.md` — never invent hex values.
- No decorative Unicode glyphs in QML — bitmap fonts render them unevenly; pixel primitives (Rectangles) instead.
- Do not iterate palette or fonts without explicit direction from Ars.
- Root-owned `/etc` configs are never symlinked: module `install.sh` (backup, validate, reload) is the source of truth.
- User configs deploy via stow; every stow package with non-config top-level files carries `.stow-local-ignore`.
- Repo is the single source: edit here, deploy out; never hand-edit deployed copies.
- Trim before adding; this file obeys its own budgets (§META).

## Stack map

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

| Module | What | Deploy | Lands |
|---|---|---|---|
| bin/ | user scripts (`pd-bt`) | symlink | `~/.local/bin` |
| crossgrub/ | GRUB theme + Terminess .pf2 fonts | install.sh | GRUB theme dir |
| fastfetch/ | fetch config + ascii art | stow | `~/.config/fastfetch` |
| firefox/ | `user.js` hardening/theme prefs | install.sh | live `*.default-release` profile (random dir name — not stow-able) |
| fish/ | shell config (login shell) | stow | `~/.config/fish` |
| fontconfig/ | Terminus alias; Terminess AA-off on native px sizes only | stow | `~/.config/fontconfig` |
| gtk/ | GTK3 theme/settings | stow + apply.sh, icons-install.sh | `~/.config/gtk-*` |
| hid_apple/ | external kbd F1-F12 fix (fnmode=2) | install.sh | `/etc/modprobe.d` |
| keyd/ | CapsLock→F19 = nvim leader; Shift+Caps = real CapsLock | install.sh | `/etc/keyd` |
| kitty/ | terminal (Terminess 12pt, Sky Paper) | stow | `~/.config/kitty` |
| mako/ | notifications (Quiet/DND wired to CC) | stow | `~/.config/mako` |
| nftables/ | firewall ruleset (see Security) | install.sh | `/etc/nftables.conf` + `/etc/nftables.d/` |
| niri/ | Wayland compositor config | stow | `~/.config/niri` |
| nvim/ | editor (Sky Paper lualine, CapsLock leader) | stow | `~/.config/nvim` |
| obsidian/ | Sky Paper snippet, vimrc, hotkeys | install.sh | per-vault `.obsidian/` (not XDG) |
| quickshell/ | bar + control center + locker + launcher + polkit rules/set-epp | stow (dir symlink; rules/set-epp manual sudo install) | `~/.config/quickshell`; `/etc/polkit-1/rules.d`, `/usr/local/bin` |
| quickshell-greeter/ | greetd greeter (mirrors lock state-machine) | install.sh | `/etc/quickshell-greeter` + `/etc/greetd/config.toml` |
| sshd/ | hardening drop-in (see Security) | install.sh | `/etc/ssh/sshd_config.d/00-hardening.conf` |
| swayidle/ | idle pipeline: 5m dim → 10m lock+screen-off → 30m suspend | stow | `~/.config/swayidle` |
| sysctl/ | kernel hardening pins (see Security) | install.sh | `/etc/sysctl.d/99-hardening.conf` |
| tlp/ | battery charge thresholds 85/90 drop-in | install.sh | `/etc/tlp.d/00-aru.conf` |
| tmux/ | multiplexer (Sky Paper statusline, TPM) | stow | `~/.config/tmux` |
| wallpapers/ | `clouds.png` (Sky Paper source image) | manual copy | `~/Pictures/wallpapers/` |
| yazi/ | file manager (Sky Paper theme, Esc→leave) | stow + install.sh (preview deps) | `~/.config/yazi` |
| zathura/ | PDF/ePub/CBZ viewer (mupdf backend) | stow + install.sh (pkgs, xdg-mime) | `~/.config/zathura` |

### Packages

- `packages.txt` is the authoritative list — names only (`pacman -Qqe` format, no versions). Must be generated on the laptop itself; this repo copy carries a placeholder until then.
- Non-obvious keepers: `passim` (masked, not removed — hard dep of fwupd); `swaylock` binary (stow package deleted; kept as manual fallback lock); `cage` (marked `--asexplicit`, the greeter runs on it); `smartmontools` (battery/disk health alongside TLP).

## Security posture

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

Deltas from Arch defaults only. Each fact has a live verify command.

- sshd drop-in `etc/ssh/sshd_config.d/00-hardening.conf`. sshd uses FIRST-obtained-value-wins, so the `00-` prefix sorts our file first among drop-ins and our values take precedence (the old `99-` name sorted last and any other drop-in would have overridden it; `install.sh` removes the old `99-` file).
  Verify: `ls /etc/ssh/sshd_config.d/ && sudo sshd -T | grep -Ei 'passwordauth|kbdinteractive|permitroot|permitempty|x11forwarding'`
- Effective sshd: PasswordAuthentication no, KbdInteractiveAuthentication no, PermitRootLogin no, PermitEmptyPasswords no, X11Forwarding no. No `~/.ssh/authorized_keys` exists → inbound SSH is currently impossible; run `ssh-copy-id` from another machine before ever needing it. Outbound unaffected.
- nftables: single inet table; input policy DROP and forward policy DROP (laptop — no Docker/libvirt). Verdicts across nft tables are ANDed: if Docker ever lands, its iptables-nft accept rules would NOT override our drop — celestia runs forward accept for exactly that reason.
  Verify: `sudo nft list ruleset | grep -E 'policy|counter'`
- nftables ordering invariant: DHCP allow (udp sport 67 dport 68; v6 sport 547 dport 546) must stay ABOVE `ct state invalid drop` — DHCP replies classify INVALID and renewal breaks silently otherwise. Reject rule is `pkttype host` + rate-limited; broadcast/multicast fall to silent drop. `iif lo accept`; inbound-ssh and virbr0 rules stay commented until needed; mDNS (5353) not allowed.
- sysctl `99-hardening.conf` pins: `kernel.kptr_restrict=1`, `kernel.yama.ptrace_scope=1`, `kernel.randomize_va_space=2`, `net.ipv4.conf.*.rp_filter=1`, ICMP redirects off (accept_redirects=0, send_redirects=0), `net.ipv4.tcp_syncookies=1`. `ip_forward` stays COMMENTED — no containers on this laptop.
  Verify: `sysctl kernel.kptr_restrict kernel.yama.ptrace_scope kernel.randomize_va_space net.ipv4.conf.all.rp_filter net.ipv4.conf.all.accept_redirects net.ipv4.tcp_syncookies net.ipv4.ip_forward`
- sysctl complements nftables, doesn't overlap: nftables filters packets on netfilter hooks; sysctl closes kernel-side holes a firewall can't (ICMP-redirect route poisoning, KASLR pointer leaks, spoofed-source route lookups).
- `passim.service` masked (fwupd metadata cache listening on 0.0.0.0:27500; can't disable — socket-activated with no [Install]; can't remove — fwupd hard dep).
  Verify: `systemctl is-enabled passim.service; ss -tlnp | grep 27500`
- Scoped polkit rules (user `aru` + exact program only): `49-bluetooth-toggle.rules` (start/stop bluetooth.service from CC), `49-epp-toggle.rules` + `/usr/local/bin/set-epp` (token-whitelisted EPP writes, password-less pkexec).
  Verify: `ls /etc/polkit-1/rules.d/ && pkexec /usr/local/bin/set-epp balance_performance`

## Machine deltas (vs celestia)

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

- `tlp/` module exists only here (charge thresholds 85/90; EPP left to TLP defaults).
- quickshell has battery-driven extras celestia lacks: Battery bar widget, EPP power-profile cycler (CC row, debounced pkexec), Auto-suspend inhibit toggle (systemd-inhibit).
- X280 exposes no `/sys/firmware/acpi/platform_profile` — the power knob here is EPP, not platform_profile or power-profiles-daemon.
- nftables forward policy: DROP here; celestia runs ACCEPT (Docker). `ip_forward`: commented here; enabled on celestia.
- Wi-Fi and Bluetooth exist here: WifiCtl/BtCtl singletons + CC rows, rfkill airplane toggle — no celestia counterpart.
- swayidle idle/suspend pipeline is laptop-specific (battery); includes lid/suspend handling.
- Greeter here has features not yet ported to celestia: any-key-reveal, power keys, battery display.
- `hid_apple/` (external keyboard fix) and `crossgrub/` currently live only in this repo.

## §META — maintenance rules

Verified: 2026-07-11 (from repo files; live laptop state not re-checked — this copy is edited on the PC)

Root whitelist — module dirs plus exactly: `README.md`, `CLAUDE.md`, `CONTEXT.md`, `PALETTE.md`, `packages.txt`, `.gitignore`, `bin/`, `docs/`. Anything else at root is a violation: move it into a module or `docs/`, or delete it.

Line budgets — Machine identity ~12, Ideology ~12 bullets, Stack map ~1 line/module, Security ~30, Deltas ~15, §META ~25; whole file under ~120. Breaching a budget means trimming before committing, never raising the budget.

Update triggers:
- Changed a module → update its Stack-map line in the same commit.
- Installed/removed a package → update `packages.txt` in the same sitting.
- `Verified:` stamps are per-section; a stamp older than the newest related file change means the section is suspect — re-verify before trusting it.

Packages drift check (run at the start of any repo work session, on the laptop):
`diff <(grep -v '^#\|^$' packages.txt | sort) <(pacman -Qqe | sort)`

Banned content in this file: history/narration (→ `docs/journal-2026.md`, `git log`), todos (→ Obsidian), how-to walkthroughs (→ module READMEs), package versions.
