# Cleanup finish plan — parked 2026-07-11

Continuation of docs/superpowers/specs/2026-07-11-repo-structure-design.md
(executed) and the 2026-07-11 two-repo audit. Pick any group; items are
atomic. Ars runs all deploys and commits.

## 1. Deploy what's already fixed (celestia, ~15 min)

- [ ] `~/celestia/firefox/install.sh` then restart Firefox — first real
      deploy of user.js; verify `browser.link.open_newwindow.restriction`
      in about:config
- [ ] `sudo ~/celestia/sysctl/install.sh` — applies the two new pins
      (ptrace_scope, randomize_va_space)
- [ ] `stow -d ~/celestia -t ~ xdg` — deploys mimeapps.list (replaces the
      live unmanaged copy; diff first)
- [ ] `stow -d ~/celestia -t ~ bin` — pd-bt onto PATH
- [ ] `pacman -S pd` — the one missing pd-bt dependency
- [ ] sshd installer only if/when sshd ever gets enabled here

## 2. Decisions (P2 minimalism, each = the three questions)

- [ ] postgresql — whim or deliberate?
- [ ] tealdeer — confirmed keeper? (replaced tldr)
- [ ] xfce4/ module — fossil verdict stands: salvage the one intentional
      line (`TerminalEmulator=kitty`, Thunar "Open Terminal Here") into a
      module or drop Thunar entirely, then delete xfce4/
- [ ] bun at ~/.bun — export to PATH or delete the dir
- [ ] font de-dup — terminus-font (X11 bitmap) vs ttf-terminus-nerd on
      pure Wayland; otf-unifont only if glyph gaps actually hit

## 3. Laptop sync (on the X280 itself)

- [ ] pull the laniakea branch into ~/dotfiles
- [ ] `pacman -Qqe` → packages.txt (replace placeholder), commit
- [ ] re-verify CONTEXT.md section stamps against the live machine
- [ ] `sudo sshd/install.sh` (sshd is live there — renames drop-in to
      00-, removes old 99-) and `sudo sysctl/install.sh`
- [ ] obsidian/install.sh with Obsidian closed (moonstone fix)

## 4. Module READMEs (gotchas evicted from CONTEXT.md by budgets)

- [ ] niri/README.md — sync-ws binds, #F0EBE0 fallback bg, XCURSOR
      exports, redundant fish DISPLAY export, playerctl/wpctl wiring
- [ ] quickshell/README.md — layer-shell PanelWindow + keyboardFocus
      Exclusive (why not PopupWindow grabs), barScreen follows focus
- [ ] quickshell-greeter/README.md — boots-clean-from-cold note, no ly
      fallback anymore
- [ ] keyd/README.md — Shift+CapsLock rationale (Fn never reaches OS)
- [ ] hid_apple/README.md — fnmode reload procedure
- [ ] mirror the same READMEs into laniakea where the module exists

## 5. P1 code cleanups (from the audit checklist)

- [ ] niri config.kdl — strip stale commented-out rules / tutorial
      comments
- [ ] ControlCenter QML — repeated row boilerplate → shared row component
- [ ] fish config nits (dead DISPLAY export after niri env block, etc.)
- [ ] crossgrub + yazi install.sh — align to the standard installer
      pattern (sudo check, backup-once, validate, rollback hint)
- [ ] tmux: xclip fallback → wl-clipboard only

## 6. P3 convergence (bigger, sequenced last)

- [ ] port greeter features laniakea → celestia (any-key-reveal, power
      keys; battery display stays laptop-only)
- [ ] unified niri config experiment: machine-specific output blocks are
      inert on the other machine — try one shared config.kdl
- [ ] sysctl: shared hardening file + celestia-only ip_forward drop-in
- [ ] converge module sets where cheap (hid_apple/crossgrub exist in both
      already; keep nftables honestly forked)

## 7. Move to Obsidian (not repo work — listed once, then delete this line)

wlsunset wiring · swap activation · BitLocker drive plan · dnscrypt
blocklist regen cadence · laniakea: CC end-to-end QA, battery/perf review
pass, backup strategy, plymouth decision, audio player + image viewer picks
