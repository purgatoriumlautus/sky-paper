# celestia Sky Paper — Phase 1+2 Implementation Plan (install + repo adaptation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the Sky Paper stack alongside the running Hyprland stack (removing nothing) and build `~/celestia` into a deploy-ready canonical repo adapted for this desktop — without deploying anything.

**Architecture:** Two reversible phases. Phase 1 is pure `pacman -S --needed` (no removals, Hyprland/ly untouched). Phase 2 copies laniakea's packages into `~/celestia`, applies the `aru→segfault` / `laniakea→celestia` renames, rewrites niri for dual-monitor, trims Quickshell to celestia's hardware, and stages merged nftables/sysctl — all as files in the repo, zero symlinks created, `/etc` untouched.

**Tech stack:** Arch/pacman, GNU Stow, niri (KDL), Quickshell (QML), nftables, sysctl, fish, git.

**Working rule for this project:** Per the user's explicit instruction, Claude does the authoring — complete configs, full edits, automation. No "describe-only / user-writes" gating. User curates and reviews.

**Preconditions:** clean baseline (Phase 0 done); `~/celestia` is a git repo with the design spec committed; logged in as `admni` (rename to `segfault` is a LATER phase — configs are written to target `/home/segfault` in anticipation).

---

## Phase 1 — Install, remove nothing

### Task 1.1: Install Sky Paper repo packages

**Files:** none (system packages).

- [ ] **Step 1: Install.** All targets are in `extra`; already-present ones are skipped by `--needed`.

```bash
sudo pacman -S --needed \
  niri quickshell greetd fish \
  zathura zathura-pdf-mupdf \
  keyd swayidle swaybg \
  terminus-font ffmpegthumbnailer qt6-declarative
```

(Already installed, not re-fetched: `otf-unifont`, `poppler`, `qt6-base`, `qt6-svg`, `fastfetch`, `xdg-desktop-portal-gtk`.)

- [ ] **Step 2: Verify the new binaries exist.**

```bash
niri --version && qs --version && greetd --version && fish --version && zathura --version
```
Expected: each prints a version, no "command not found".

- [ ] **Step 3: Verify NOTHING was removed (old stack intact).**

```bash
pacman -Q hyprland waybar tofi hyprpaper ly 2>&1
```
Expected: all five still report installed versions. If any say "was not found", STOP — a removal happened.

- [ ] **Step 4: No commit** (Phase 1 changes no repo files).

### Task 1.2: Snapshot package state into the repo

**Files:** Create `~/celestia/packages.txt`

- [ ] **Step 1: Write the explicit + foreign package list.**

```bash
{ echo "# celestia explicit packages — $(date -I)"; pacman -Qe; echo "# --- foreign/AUR ---"; pacman -Qm; } > ~/celestia/packages.txt
```

- [ ] **Step 2: Commit.**

```bash
cd ~/celestia && git add packages.txt && git commit -m "Snapshot package state after Sky Paper install"
```

---

## Phase 2 — Build & adapt ~/celestia (no deploy)

### Task 2.1: Scaffold the repo from laniakea

**Files:** Create package dirs under `~/celestia/`

- [ ] **Step 1: Copy adopted packages** (exclude `tlp` — dropped; exclude laniakea's `docs/`, `.git`, `screenshots`, `CONTEXT.md` — we keep our own).

```bash
cd ~/laniakea
for pkg in niri quickshell quickshell-greeter kitty nvim tmux fish mako yazi \
           zathura fontconfig gtk fastfetch obsidian firefox wallpapers \
           keyd hid_apple crossgrub sshd swayidle nftables sysctl; do
  cp -r "$pkg" ~/celestia/
done
cp PALETTE.md ~/celestia/
```

- [ ] **Step 2: Verify tlp was NOT copied and the rest are present.**

```bash
ls ~/celestia/ | sort; test ! -e ~/celestia/tlp && echo "tlp correctly absent"
```
Expected: all listed pkgs present, `tlp correctly absent`.

- [ ] **Step 3: Commit.**

```bash
cd ~/celestia && git add -A && git commit -m "Scaffold: import laniakea Sky Paper packages (minus tlp)"
```

### Task 2.2: Rename user aru → segfault

**Files:** Modify all under `~/celestia` containing `aru` / `/home/aru`.

- [ ] **Step 1: Enumerate occurrences (for the record).**

```bash
cd ~/celestia && grep -rIn -e '/home/aru' -e '\baru\b' . | grep -v '\.git/'
```
Expected hits: niri config (swaybg), quickshell LockScreen.qml, AppLauncher.qml (×3), epp-toggle.rules, bluetooth-toggle.rules (deleted later), set-epp, quickshell-greeter install.sh + Theme.qml/BigClock.qml comments, fontconfig obsidian.desktop.

- [ ] **Step 2: Replace.** `/home/aru` first (longer), then bare `aru`.

```bash
cd ~/celestia
grep -rIl -e '/home/aru' -e '\baru\b' . | grep -v '\.git/' | \
  xargs sed -i -e 's#/home/aru#/home/segfault#g' -e 's/\baru\b/segfault/g'
```

- [ ] **Step 3: Verify zero remaining.**

```bash
cd ~/celestia && grep -rIn -e '/home/aru' -e '\baru\b' . | grep -v '\.git/' || echo "clean: no aru references"
```
Expected: `clean: no aru references`.

- [ ] **Step 4: Commit.**

```bash
cd ~/celestia && git add -A && git commit -m "Rename user aru -> segfault across all configs"
```

### Task 2.3: Rename host laniakea → celestia

**Files:** Modify all under `~/celestia` containing `laniakea`.

- [ ] **Step 1: Replace** (skip binary/screenshot and the spec docs which legitimately reference the source tree).

```bash
cd ~/celestia
grep -rIl 'laniakea' . | grep -vE '\.git/|docs/superpowers/' | \
  xargs sed -i 's/laniakea/celestia/g'
```

- [ ] **Step 2: Verify.**

```bash
cd ~/celestia && grep -rIn 'laniakea' . | grep -vE '\.git/|docs/superpowers/' || echo "clean: no laniakea host refs"
```
Expected: `clean`.

- [ ] **Step 3: Commit.**

```bash
cd ~/celestia && git add -A && git commit -m "Rename host laniakea -> celestia in configs"
```

### Task 2.4: niri — dual-monitor output + 3-layout input

**Files:** Modify `~/celestia/niri/.config/niri/config.kdl`

- [ ] **Step 1: Replace the single `output "eDP-1" { … }` block** (the active one around the stock example) with two real outputs. Ground truth from `hyprctl monitors`: DP-3 left @165, DP-2 right @144.

```kdl
output "DP-3" {
    mode "1920x1080@165.000"
    scale 1
    transform "normal"
    position x=0 y=0
}

output "DP-2" {
    mode "1920x1080@144.000"
    scale 1
    transform "normal"
    position x=1920 y=0
}
```

- [ ] **Step 2: Set keyboard layouts** in the `input { keyboard { xkb { … } } }` block: change `layout "us,ru"` → `layout "us,ru,ua"` (keep `options "grp:alt_shift_toggle"`).

- [ ] **Step 3: Fix the cursor block.** The copied config still names `Chicago95_Standard_Cursors` (lines ~76-79) — wrong theme for Sky Paper. Set to the Sky Paper cursor the gtk package installs (confirm exact name from `~/celestia/gtk`; if unset there, use `"Adwaita"` size 24 as a safe default and flag for review).

- [ ] **Step 4: Validate (niri installed in Phase 1).**

```bash
niri validate -c ~/celestia/niri/.config/niri/config.kdl && echo "niri config OK"
```
Expected: `niri config OK`, no parse errors. (Validation does not require a running niri.)

- [ ] **Step 5: Commit.**

```bash
cd ~/celestia && git add niri && git commit -m "niri: dual-monitor (DP-3 165Hz left, DP-2 144Hz right) + us,ru,ua layouts"
```

### Task 2.5: Trim Quickshell to celestia hardware (delete dead modules)

celestia has **no backlight, no wifi, no bluetooth**. Modules with nothing to drive: Brightness, Wifi (+WifiCtl/WifiRow), BT (+BtCtl/BtRow), Radio/Airplane (rfkill). Battery is the wireless-mouse only — drop from the bar.

**Files:** Delete under `~/celestia/quickshell/.config/quickshell/`: `Battery.qml`, `Brightness.qml`, `BtCtl.qml`, `BtRow.qml`, `WifiCtl.qml`, `WifiRow.qml`, `Radio.qml`, `bluetooth-toggle.rules`. Keep `OutputRow.qml`, `AudioCtl.qml`, `Power.qml`, `PowerRow.qml`, `set-epp`, `epp-toggle.rules` (EPP works on amd-pstate-epp).

- [ ] **Step 1: Delete the dead module files.**

```bash
cd ~/celestia/quickshell/.config/quickshell
git rm Battery.qml Brightness.qml BtCtl.qml BtRow.qml WifiCtl.qml WifiRow.qml Radio.qml bluetooth-toggle.rules
```

- [ ] **Step 2:** Do NOT commit yet — `Bar.qml` and `ControlCenter.qml` still reference these (Task 2.6 rewires them in the same commit). Proceed directly to 2.6.

### Task 2.6: Rewire Bar.qml + ControlCenter.qml for the trimmed module set

**Files:** Modify `Bar.qml`, `ControlCenter.qml` in `~/celestia/quickshell/.config/quickshell/`

**Row remap** (main section shrinks 10→6; power rows stay 10/11):

| old idx | row | new idx |
|--------|-----|---------|
| 0 | Brightness | **removed** |
| 1 | Volume | 0 |
| 2 | Airplane | **removed** |
| 3 | Warm | 1 |
| 4 | Auto-suspend | 2 |
| 5 | Quiet | 3 |
| 6 | BT | **removed** |
| 7 | Wifi | **removed** |
| 8 | Output | 4 |
| 9 | Power profile (EPP) | 5 |

- [ ] **Step 1: Bar.qml** — remove the `Battery { anchorWin: bar }` line (right-side Row) and the `Wifi { anchorWin: bar }` line. Leaves `Language` + the `λ` control-center toggle.

- [ ] **Step 2: ControlCenter.qml — `refresh()`** (≈line 74): drop `Brightness.refresh();`, `Radio.refresh();`, `WifiCtl.refreshActive();`, `BtCtl.refreshActive();`. Keep `NightLight.refresh();`, `Power.refresh();`, `Notifications.refresh();`.

- [ ] **Step 3: Remove the WifiCtl and BtCtl `Connections` blocks** (≈lines 94-107). Keep the AudioCtl one but update its row check: `cc.openRow === 8` → `cc.openRow === 4`.

- [ ] **Step 4: `advanceRow(dir)`** (≈line 146): main-section wrap `% 10` → `% 6` (keep the `>= 10` power branch unchanged).

- [ ] **Step 5: `dispatchHL(dir)`** switch — rewrite cases to new indices:
  - `0`: Volume → `cc.nudgeVolume(dir)`
  - `1`: Warm → `NightLight.toggle()`
  - `2`: Auto-suspend → `SuspendInhibit.toggle()`
  - `3`: Quiet → `Notifications.toggle()`
  - `4`: Output → `cc.openList()`
  - `5`: Power profile → `Power.cycle(dir)`
  - keep `10`/`11` power footer case as-is.

- [ ] **Step 6: `handleEnter()`** switch — new indices: `0` mute (`cc.toggleMute()`), `1` `NightLight.toggle()`, `2` `SuspendInhibit.toggle()`, `3` `Notifications.toggle()`, `4` `cc.openList()`, `5` `Power.cycle(1)`; keep `10`/`11`.

- [ ] **Step 7: list-mode** — only Output remains a list. `listLen()`: keep only `if (cc.openRow === 4) return AudioCtl.sinks.length;` (drop wifi/bt branches). `openList()`: drop the wifi/bt scan triggers. `commitList()`: keep only the Output branch (old `openRow === 8` → `4`, using `AudioCtl.sinks[cc.listSel]`). Delete `connectWifi`/`connectBt` helpers and the wifi-password state (`askingPassword`, `pendingSsid`) and the `if (cc.askingPassword) return;` guard + the `r`/`к` rescan handler in `Keys.onPressed`.

- [ ] **Step 8: Column children** (the visual rows ≈366-431): delete `CcSliderRow Brightness` (row 0), `CcToggleRow Airplane` (row 2), `BtRow` (row 6), `WifiRow` (row 7). Renumber the survivors' `rowIndex`: Volume→0, Warm→1, Auto-suspend→2, Quiet→3, OutputRow→4, PowerRow→5.

- [ ] **Step 9: Load test** (no deploy; just parse/instantiate check).

```bash
qs -p ~/celestia/quickshell/.config/quickshell/shell.qml --check 2>&1 | tail -20 || \
  echo "if --check unsupported, defer load test to Phase 4 deploy"
```
Expected: no QML errors referencing Battery/Brightness/Wifi/BtCtl/Radio. (If `--check` isn't supported by this quickshell version, note it and rely on the Phase 4 live load with the Hyprland fallback available.)

- [ ] **Step 10: Commit.**

```bash
cd ~/celestia && git add -A && git commit -m "Quickshell: trim brightness/wifi/bt/airplane/battery for desktop hardware; renumber CC rows 0-5"
```

### Task 2.7: Stage merged nftables (composable + Docker-safe)

Adopt laniakea's composable layout and DHCP-before-invalid fix; keep celestia's **forward policy accept** (Docker manages forward via iptables-nft) and the `# Docker` note. Files are staged in the repo only — NOT deployed.

**Files:** these already exist from Task 2.1 under `~/celestia/nftables/etc/`. Edit `nftables.d/00-filter.nft`.

- [ ] **Step 1: Set the forward chain to accept** in `~/celestia/nftables/etc/nftables.d/00-filter.nft`:

```nft
  chain forward {
    type filter hook forward priority filter; policy accept;
    # Docker manages its own forward rules via iptables-nft.
  }
```
(Leave the `input` chain as laniakea's — DHCP allow before `ct state invalid drop`, rate-limited reject, ssh/virbr0 commented.)

- [ ] **Step 2: Show the diff vs the live celestia ruleset** (review gate).

```bash
diff <(sudo cat /etc/nftables.conf) ~/celestia/nftables/etc/nftables.conf; \
echo '--- new composable filter ---'; cat ~/celestia/nftables/etc/nftables.d/00-filter.nft
```

- [ ] **Step 3: Syntax-validate the staged ruleset** (combine entry+filter into a temp file so the `include` resolves).

```bash
tmp=$(mktemp); printf 'flush ruleset\n' > "$tmp"; cat ~/celestia/nftables/etc/nftables.d/00-filter.nft >> "$tmp"; \
sudo nft -c -f "$tmp" && echo "nftables syntax OK"; rm "$tmp"
```
Expected: `nftables syntax OK`.

- [ ] **Step 4: Commit.**

```bash
cd ~/celestia && git add nftables && git commit -m "nftables: composable layout + DHCP fix, keep forward=accept for Docker"
```

### Task 2.8: Stage merged sysctl (keep ip_forward for Docker)

laniakea's and celestia's `99-hardening.conf` are near-identical; the only material diff is `ip_forward`. Adopt laniakea's commented structure but uncomment `ip_forward = 1` (celestia runs Docker).

**Files:** Edit `~/celestia/sysctl/etc/sysctl.d/99-hardening.conf`

- [ ] **Step 1:** In the staged file, replace the commented `# net.ipv4.ip_forward = 1` block with an active line + reason:

```ini
# IP forwarding ON — required for Docker bridge networking on celestia.
net.ipv4.ip_forward = 1
```

- [ ] **Step 2: Diff vs live.**

```bash
diff /etc/sysctl.d/99-hardening.conf ~/celestia/sysctl/etc/sysctl.d/99-hardening.conf
```
Expected: differences only in comments + the active `ip_forward = 1`.

- [ ] **Step 3: Commit.**

```bash
cd ~/celestia && git add sysctl && git commit -m "sysctl: adopt laniakea hardening, keep ip_forward=1 for Docker"
```

### Task 2.9: Phase 2 exit checks (prove nothing deployed)

- [ ] **Step 1: Repo is clean of source-host identifiers.**

```bash
cd ~/celestia && grep -rIn -e '/home/aru' -e '\baru\b' -e 'laniakea' . | grep -vE '\.git/|docs/superpowers/' || echo "identifiers clean"
```
Expected: `identifiers clean`.

- [ ] **Step 2: niri config still valid.** `niri validate -c ~/celestia/niri/.config/niri/config.kdl`

- [ ] **Step 3: No deploy happened — /etc and live symlinks untouched.**

```bash
find /etc -name '*.pacnew' -newer ~/celestia/packages.txt 2>/dev/null; \
ls -l ~/.config/niri ~/.config/quickshell 2>&1 | grep -q 'No such' && echo "no new session symlinks (expected)"
```
Expected: no new pacnew from our work; niri/quickshell NOT yet symlinked into `~/.config`.

- [ ] **Step 4: Old stack still default.** Confirm `ly` still the active DM and Hyprland session unchanged (we have not touched greetd or wayland-sessions yet).

```bash
ps -o comm= -p $(pgrep -x ly-dm | head -1) 2>/dev/null; echo "greetd not yet configured (expected)"
```

---

## Self-review

**Spec coverage (§4 dispositions):** niri Adapt → 2.4 ✓ · quickshell trim+rename → 2.5/2.6 + 2.2 ✓ · tlp drop → 2.1 (excluded) ✓ · nftables/sysctl merge → 2.7/2.8 ✓ · rename surfaces → 2.2/2.3 ✓ · package install → 1.1 ✓. Deferred to later plans (correct for Phase 1+2): greetd/two-sessions, hid_apple/keyd/crossgrub/fontconfig/sshd install.sh runs, fish chsh, stow deploy, account rename — all are Phase 3/4 (deploy), not Phase 1/2.

**Placeholder scan:** cursor theme name (2.4 step 3) and `qs --check` support (2.6 step 9) are the only conditional bits — both carry explicit fallbacks, not TODOs.

**Index consistency:** ControlCenter row remap table (2.6) is the single source; `advanceRow %6`, `dispatchHL`/`handleEnter` cases, `listLen`/`commitList` `openRow === 4`, and Column `rowIndex` values all reference it consistently.

## Open items carried to Phase 3/4 plan
- Exact Sky Paper cursor theme name (resolve from gtk package).
- `hid_apple` fnmode value vs desired F-key behavior.
- crossgrub vs current GRUB entry (replace or add).
- niri `spawn-at-startup` audit (drop any laptop-only spawns) — review at deploy.
- fish as login shell (`chsh`) — happens with/after the account rename.
