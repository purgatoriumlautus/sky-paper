# System Context — celestia

System manifest for Claude. Static snapshot, manually maintained.

**Last verified: 2026-05-30** — Bash-verified true-up of the whole doc (`pacman -Qe`,
`pacman -Qm`, `systemctl`, `lsblk`, `ip`, `wpctl`, live config reads). Corrected hardware,
storage, network, and service state; documented the new keyboard-remap subsystem
(keyd + hid_apple), the pentest/VM/media package additions, the swaybg wallpaper, and the
new repo modules. Also removed this pass: the offensive-security stack
(metasploit/nmap/hashcat/gobuster/rockyou + rocm-opencl-runtime) and gvim/cdrtools/cozette.
Authoritative package list: `~/celestia/packages.txt` (itself slightly stale — see Known
Issues). Future work lives in `~/celestia/todos.md`.

## Philosophy

**Performance-driven minimalism.** Every choice optimizes for:
1. **Responsiveness** — system should feel instant
2. **Minimal footprint** — fewest packages possible
3. **Unix philosophy** — one tool, one job, done well

The "Sky Paper" rice (niri + Quickshell) is the current aesthetic — lightweight, zero
animation/rounding/blur. The Chicago95 cursor and icon theme are retained as a deliberate
retro accent; GTK widget theme is stock Adwaita (light).

> Note: the package set has grown well past "bare minimum" — a pentest toolkit
> (metasploit/nmap/hashcat/gobuster), a full QEMU/libvirt VM stack, and desktop apps
> (libreoffice, telegram, mpv) now coexist with the minimal compositor. Minimalism still
> governs the *compositor/DE* layer; the rest is a working desktop.

Wayland over X11 by choice: simpler architecture, better-documented, isolation-by-default.

## Hardware

| Component | Value |
|-----------|-------|
| Hostname | celestia |
| Motherboard | ASUS TUF GAMING B550M-PLUS (BIOS 2803, 2022-04-27) |
| CPU | AMD Ryzen 5 5600X — 6 cores / 12 threads |
| RAM | 16GB DDR4 (no swap active) |
| GPU | AMD RX 6700 XT (Navi 22 [1002:73df], amdgpu driver) |
| Wifi | None |
| Bluetooth | None |

### Storage

| Device | Type | Size | Mount | Notes |
|--------|------|------|-------|-------|
| /dev/sdb1 | vfat | 1G | /boot | EFI system partition |
| /dev/sdb2 | swap | 4G | — | Swap partition exists but 0B active |
| /dev/sdb3 | ext4 | 227.9G | / | Root |
| /dev/sda1 | — | 16M | — | (likely MS reserved) on the 931.5G Windows disk |
| /dev/sda2 | BitLocker | 931.5G | — | Windows drive, planned for future use |

### Monitors

| Connector | Model | Resolution | Refresh | Position | Workspace |
|-----------|-------|------------|---------|----------|-----------|
| DP-3 | ASUS VG259QR | 1920x1080 | 165Hz | Left (0x0) | 1 |
| DP-2 | BenQ ZOWIE XL | 1920x1080 | 144Hz | Right (1920x0) | 2 |

Confirmed in `~/.config/niri/config.kdl` (`mode "1920x1080@165.004"` / `@144.001`).

### Keyboard

External **Epomaker x Feker Galaxy80 (X80)**. In Mac mode it reports Apple's USB vendor id
(05AC:024F), so the kernel `hid_apple` driver claims it. Two tweaks tame it:

- **hid_apple fnmode=2** (`/etc/modprobe.d/hid_apple.conf`, deployed by
  `~/celestia/hid_apple/install.sh`) — makes F1–F12 the primary top-row action (Fn for
  media) instead of the Apple-VID default that hides F-keys behind Fn. Only read when the
  module loads, so changing it needs a reboot or `modprobe -r/​modprobe hid_apple`; the
  install script also pokes the live sysfs value.
- **keyd CapsLock remap** — see Input / keyd below.

### Audio

| Component | Value |
|-----------|-------|
| Stack | PipeWire + WirePlumber |
| Primary sink | Starship/Matisse HD Audio Controller Analog Stereo (onboard) |
| Secondary sink | Navi 21/23 HDMI/DP Audio (GPU, HDMI 3 — available, not default) |
| rt-audio-setup | Enabled (oneshot) — real-time audio prep (Renoise) |

## Network

| Property | Value |
|----------|-------|
| Interface | enp5s0 (ethernet only) |
| IP | 192.168.0.x/24 (DHCP — floats; .18/.19 seen) |
| Gateway | 192.168.0.1 |
| DNS | 127.0.0.1 (dnscrypt-proxy — encrypted DoH, ad-blocking) |
| virbr0 | 192.168.122.1/24 (libvirt default NAT network; DOWN with no VMs) |
| docker0 | 172.17.0.1/16 (Docker bridge — only up when docker is running) |

No wifi or bluetooth hardware. The IP is DHCP-assigned, so don't hardcode it.

## Services

### Running (system)

| Service | Description |
|---------|-------------|
| dnscrypt-proxy | Encrypted DNS resolver with ad-blocking |
| greetd | Login daemon (Wayland greeter via cage — see Display Manager) |
| keyd | Key-remapping daemon (CapsLock → F19) |
| libvirtd | QEMU/KVM virtualization — **now running** (brings up virbr0 + its dnsmasq) |
| NetworkManager | Network management |
| dbus-broker | D-Bus system message bus |
| polkit | Authorization manager |
| rtkit-daemon | Realtime scheduling for audio |
| systemd-timesyncd | NTP time sync |
| systemd-{journald,logind,udevd,hostnamed,machined,userdbd} | core systemd |

### Running (user)

pipewire, pipewire-pulse, wireplumber (audio); niri (compositor); mako (notifications via
xdg portal); xdg-desktop-portal{,-gtk}; remmina-applet (autostart).

### Enabled but not running

| Service | Description |
|---------|-------------|
| docker.socket | Container runtime (socket-activated; docker0 only appears when active) |
| libvirtd sockets | ro/admin + virtlockd/virtlogd sockets |
| rt-audio-setup | Real-time audio prep (oneshot, RemainAfterExit) |
| nftables | Firewall (loaded at boot, runs in kernel) |

> **Orphaned unit:** a user `mpd.service` is still *active (running)* (PID from boot) even
> though the `mpd` binary and package were removed. The unit file is gone (`not-found`) but
> the process persists from before removal. Needs `systemctl --user stop mpd` (and confirm
> nothing re-spawns it). Tracked in todos.

> Sky Paper migration removed (don't re-suggest): the hyprland stack, waybar, tofi, ly,
> zsh, mpd/mpc/rmpc, upower, chicago95-gtk-theme. Roles moved: night-light hyprsunset →
> wlsunset, wallpaper hyprpaper → swaybg, DM ly → greetd. Full narrative in
> `~/celestia/hadnoff.txt` + `docs/superpowers/`.

## Display Manager

**greetd** (Phase R1, commit 91e8361). greetd launches **cage** (kiosk Wayland compositor)
which hosts a **Quickshell** greeter.

- greetd config: `~/celestia/quickshell-greeter/etc/greetd/config.toml` → `/etc/greetd/config.toml`
- Greeter command: `cage -s -m last -- env QT_QPA_PLATFORM=wayland QT_WAYLAND_DISABLE_WINDOWDECORATION=1 qs -p /etc/quickshell-greeter`
  - `-m last` pins the greeter to one output. cage's default `-m extend` spans both
    1920×1080 outputs into one surface, centering the greeter on the seam and duplicating
    it across both monitors.
- **Rescue:** if greetd fails, from a root TTY: `systemctl disable --now greetd`, then start
  niri manually or reinstall a fallback DM (`ly` is no longer installed). greetd has booted
  cleanly from cold; this is a last resort.

## Input / keyd

**keyd** (`keyd.service`, enabled + running) remaps at the evdev layer, below xkb. Config
`/etc/keyd/default.conf`, deployed by `~/celestia/keyd/install.sh` (root-owned, not stowable
— the script is the source of truth, same pattern as the greeter installer).

- tap **CapsLock → F19** — used as Neovim `<leader>`; never toggles typed case.
- **Shift + CapsLock → real CapsLock** toggle (deliberate way back to case-lock; laptop
  `Fn` never reaches the OS, so Fn+CapsLock is impossible).
- F19 specifically because, in the default `us` keymap, it is the one F13–F24 keycode that
  maps to a clean `F19` keysym (the others map to vendor keysyms terminals silently drop),
  so it actually reaches kitty → tmux → nvim.

## Security Posture

### Firewall (nftables)

- **Input policy:** drop (default deny)
- Allowed: established/related, loopback, ICMP
- Rate-limited reject for unsolicited host packets (5/sec)
- **Forward policy:** accept (Docker manages its own forward rules via iptables-nft)
- **Output policy:** accept
- Config: `/etc/nftables.conf` (repo: `~/celestia/nftables/`)

### sysctl Hardening

Config: `/etc/sysctl.d/99-hardening.conf` (repo: `~/celestia/sysctl/`)

| Setting | Value | Purpose |
|---------|-------|---------|
| kernel.kptr_restrict | 1 | Hide kernel pointers from non-root |
| kernel.yama.ptrace_scope | 1 | Restrict ptrace to parent processes |
| kernel.randomize_va_space | 2 | Full ASLR enabled |
| net.ipv4.ip_forward | 1 | Required for Docker |
| net.ipv4.conf.all.rp_filter | 1 | Reverse path filtering (anti-spoof) |
| net.ipv4.conf.all.accept_redirects | 0 | Reject ICMP redirects |
| net.ipv4.conf.all.send_redirects | 0 | Don't send ICMP redirects |
| net.ipv4.tcp_syncookies | 1 | SYN flood protection |

### Other

- **SSH:** installed, **disabled + inactive**. A hardening drop-in is staged in the repo
  (`~/celestia/sshd/etc/ssh/sshd_config.d/99-hardening.conf`, manual install) for when it's
  ever turned on.
- **Firefox hardening:** `~/celestia/firefox/user.js` (manual install). Currently scoped to
  forcing `window.open` popups into tabs (works around niri tiling firefox popup windows as
  half-screen siblings because they share `app_id` and set the title after mapping).
- **faillock:** active (`/etc/pam.d/system-auth`) — locks account after failed sudo attempts.

## Installed Packages

> Authoritative list: `~/celestia/packages.txt`. 111 explicit packages (`pacman -Qe`),
> 6 foreign (`pacman -Qm`). The role map below is curated, not exhaustive.

### Compositor / DE (Sky Paper)

niri (scrollable Wayland WM), quickshell + qt6-declarative (bar/control-center/launcher/
greeter), cage (greeter host), greetd, mako (notifications), swayidle (idle→suspend),
swaybg (wallpaper), wlsunset (night light — **installed, not currently running**),
xdg-desktop-portal, xorg-xwayland

### Input

keyd (CapsLock→F19 remap)

### Terminal / Shell / Editor

kitty, fish, tmux, neovim, nano

### File Management

thunar, tumbler, ffmpegthumbnailer, yazi, 7zip, zip, unzip

### Media / Audio

pipewire (+alsa/jack/pulse), wireplumber, alsa-utils, pavucontrol, playerctl (media keys),
mpv, nomacs (image viewer)

### Desktop Applications

firefox, obsidian, zathura (+zathura-pdf-mupdf), libreoffice-fresh, telegram-desktop

### Remote Desktop / Networking

remmina + freerdp (RDP client), openvpn (VPN), whois, python-pyotp (TOTP/2FA)

### Clipboard / Screenshots

wl-clipboard, cliphist, grim, slurp, satty

### Networking

networkmanager, dnscrypt-proxy, dnsmasq (libvirt dependency)

### Virtualization

docker, qemu-full, qemu-guest-agent, libvirt, virt-manager, virt-viewer, spice, spice-gtk,
swtpm (software TPM), virtio-win, iptables

### Dev / Build Toolchain

git, go, npm + node, python-pip, cmake, tree-sitter-cli, base-devel, devtools, debugedit

### CLI Utilities

bat, btop, eza, fd, fzf, zoxide, tldr, fastfetch, ncdu, lsof, tree, plocate, pacman-contrib,
jq, man-db, stow, sudo

### Boot / Firmware

grub, efibootmgr, amd-ucode, linux, linux-firmware, mkinitcpio deps (cpio)

### Fonts

ttf-terminus-nerd + terminus-font, ttf-nerd-fonts-symbols(-mono), otf-unifont,
ttf-dejavu, noto-fonts(-cjk/-emoji)

### AUR / foreign (`pacman -Qm`)

xcursor-chicago95-git (cursor — KEPT), chicago95-icon-theme-git (icons — KEPT), nomacs,
yay, otf-unifont, virtio-win

### Runtime (not via pacman)

- **bun:** installed at `~/.bun` but **NOT on PATH** right now (was previously exported).
- **nvm:** **removed** (`~/.nvm` no longer exists). Node is now the system `npm`/`node`
  pacman package (`node v26.2.0`), and `go` is the system package too.

## Stow Structure

Canonical repo is `~/celestia/` (GNU Stow, user-level). System-level configs (greetd,
keyd, hid_apple, nftables, sysctl, sshd, grub theme) live outside `$HOME`, so they are
**reference-only and deployed manually** via per-module `install.sh` scripts (not stow).

```
~/celestia/
├── fish/         → ~/.config/fish/
├── niri/         → ~/.config/niri/
├── quickshell/   → ~/.config/quickshell/
├── kitty/        → ~/.config/kitty/
├── tmux/         → ~/.config/tmux/
├── nvim/         → ~/.config/nvim/
├── mako/         → ~/.config/mako/
├── swayidle/     → ~/.config/swayidle/
├── gtk/          → ~/.config/gtk-{3.0,4.0}/
├── yazi/         → ~/.config/yazi/
├── fastfetch/    → ~/.config/fastfetch/
├── zathura/      → ~/.config/zathura/
├── xfce4/        → ~/.config/xfce4/ (Thunar settings)
├── fontconfig/   → ~/.config/fontconfig/
│
│   # manual (install.sh), system-level / outside $HOME:
├── quickshell-greeter/ → /etc/quickshell-greeter/ + /etc/greetd/
├── keyd/         → /etc/keyd/default.conf
├── hid_apple/    → /etc/modprobe.d/hid_apple.conf
├── nftables/     → /etc/nftables.conf
├── sysctl/       → /etc/sysctl.d/99-hardening.conf
├── sshd/         → /etc/ssh/sshd_config.d/99-hardening.conf (SSH off)
├── firefox/      → user.js (firefox profile)
├── crossgrub/    → GRUB theme (Crossgrub, install.sh + .pf2 fonts + assets)
│
│   # data / docs (not deployed):
├── wallpapers/   → source wallpapers (clouds.png; live copy in ~/Pictures/wallpapers/)
├── docs/         → superpowers plans + specs (Sky Paper transition history)
├── packages.txt  → authoritative explicit-package list
├── PALETTE.md    → color palette reference
├── CONTEXT.md / CLAUDE.md / todos.md
└── hadnoff.txt   → migration handoff notes (filename typo'd)
```

## Compositor / DE

### niri

- **Config:** `~/.config/niri/config.kdl` (symlink from `~/celestia/niri`)
- Scrollable-tiling Wayland WM. Per-output workspaces, columns scroll horizontally.
- Mod key: SUPER. Vim-style HJKL navigation.
- **Spawn-at-startup:** `qs` (Quickshell), `swaybg -i ~/Pictures/wallpapers/clouds.png -m fill`,
  `swayidle -w`, `mako`. Fallback workspace background `#F0EBE0` if swaybg isn't running.
- Media keys (`XF86Audio*`) spawn `playerctl`; volume keys use `wpctl`.
- `Mod+1..9` run `~/.config/niri/scripts/sync-ws N` (per-output workspace sync).
- Cursor: `Chicago95_Standard_Cursors` (XCURSOR_THEME/SIZE exported for spawned apps).

### Quickshell

- **Config:** `~/.config/quickshell/` (symlink from `~/celestia/quickshell`)
- One **Bar** per monitor (`Variants` over `Quickshell.screens`).
- A single shared **ControlCenter** + **Launcher** as keyboard-focusable wlr-layer-shell
  surfaces (`PanelWindow`, `WlrLayer.Overlay`, `keyboardFocus: Exclusive` while visible,
  `exclusionMode: Ignore`). They follow the focused output via `barScreen`. NOT grabbing
  `PopupWindow`s — a grab needs the parent bar to have received input, which a
  compositor-consumed keybind never delivers.
- IPC: `qs ipc call controlcenter|launcher toggle` (and `qs ipc call lock lock`).
- Also hosts the greetd greeter (`/etc/quickshell-greeter`) and a LockScreen.

### Idle / Notifications

- **swayidle** (`swayidle -w`) → idle-triggered suspend / lock.
- **mako** → notification daemon.

## Shell / Terminal / Editor

### fish

- Login shell (`chsh` to `/usr/bin/fish`). Config: `~/.config/fish/` (from `~/celestia/fish`).
- Replaced zsh, which has been removed.

### kitty

- **Config:** `~/.config/kitty/kitty.conf` (symlink from `~/celestia/kitty`)
- Auto-launches tmux session `main` on open.

### tmux

- **Config:** `~/.config/tmux/tmux.conf` (symlink from `~/celestia/tmux`)

### Neovim

- **Config:** `~/.config/nvim/init.lua` (symlink from `~/celestia/nvim`)
- lazy.nvim; LSP via mason; telescope; nvim-tree; gitsigns; which-key.
- `<leader>` is F19, emitted by the keyd CapsLock remap (see Input / keyd).

## Aesthetic

Sky Paper: niri + Quickshell, lightweight and flat. Zero animations, zero rounding, zero
blur, shadows off. Chicago95 cursor + icon theme retained as a retro accent; GTK widget
theme is Adwaita (light). Wallpaper: `clouds.png`. Palette reference: `~/celestia/PALETTE.md`.

| Element | Value |
|---------|-------|
| GTK Theme | Adwaita |
| Icons | Chicago95 |
| Cursor | Chicago95_Standard_Cursors |
| Font | Terminess Nerd Font Mono |

## Known Issues / Pending

> Active future work and ideas live in `~/celestia/todos.md`. This list is only the
> system-state caveats a reader of *this* doc needs.

- [ ] **Orphaned `mpd.service`** (user) still running though mpd was removed — stop it and
      confirm nothing re-spawns it.
- [ ] `packages.txt` is slightly stale vs live `pacman -Qe` — regenerate.
- [ ] `CONTEXT.md` / `CLAUDE.md` / `todos.md` and the `xfce4/` migration are untracked in
      git — commit them.
- [ ] **wlsunset** installed but not running/configured — wire up night light if wanted.
- [ ] `bun` installed at `~/.bun` but not on PATH — decide keep-and-export vs remove.
- [ ] Swap partition (sdb2, 4G) exists but not active.
- [ ] sda BitLocker drive (931.5G) — planned for future use, not yet set up.
- [ ] dnscrypt-proxy blocklist needs periodic regeneration.

## Update Instructions

**For Claude:** Update this file whenever system changes are made during a session. Bump the
"Last verified" date on each update. Only document current factual state — no planned or
aspirational content except in Known Issues (future work goes in `todos.md`).
