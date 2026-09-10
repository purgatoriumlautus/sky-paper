#!/usr/bin/env bash
# Install the keyd modifier remap. Run with sudo.
#
# Why a script and not stow: keyd reads /etc/keyd/default.conf, which is
# root-owned and outside $HOME — not stow-able. This script is the source
# of truth (same reasoning as quickshell-greeter/install.sh).
#
# What it does:
#   tap CapsLock     -> Ctrl (home-row modifier; never affects typed case)
#   Shift + CapsLock -> real CapsLock toggle
#   bottom-left Ctrl -> Menu (keyboard-layout switch; see the config)
#   Fn (arrives as rightalt) -> Fn row: mute/volume/mic/brightness on F1-F6
#
# Rationale and the full keybinding scheme: docs/keybinds.md
#
# Note: a stock laptop Fn never reaches the OS, so Fn+CapsLock is impossible
# and Shift+CapsLock is the deliberate way back to case-lock. The Fn key on
# this machine was remapped to emit rightalt, which is why the config can
# rebuild the F-row functions on a [fnrow] layer.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Back up an existing config once.
[[ -f /etc/keyd/default.conf && ! -f /etc/keyd/default.conf.bak ]] \
    && cp /etc/keyd/default.conf /etc/keyd/default.conf.bak
install -d -m 755 /etc/keyd
install -m 644 "$SRC/etc/keyd/default.conf" /etc/keyd/default.conf

systemctl enable --now keyd
systemctl restart keyd

echo "Installed. CapsLock = Ctrl; Shift+CapsLock = real CapsLock; corner Ctrl = layout switch; Fn+F1-F6 = volume/mic/brightness."
echo "Rollback: restore /etc/keyd/default.conf.bak (or rm it) && systemctl restart keyd"
