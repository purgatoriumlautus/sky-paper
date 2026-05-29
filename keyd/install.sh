#!/usr/bin/env bash
# Install the keyd CapsLock remap. Run with sudo.
#
# Why a script and not stow: keyd reads /etc/keyd/default.conf, which is
# root-owned and outside $HOME — not stow-able. This script is the source
# of truth (same reasoning as quickshell-greeter/install.sh).
#
# What it does:
#   tap CapsLock     -> F19  (Neovim <leader>; never affects typed case)
#   Shift + CapsLock -> real CapsLock toggle
#
# Note: laptop Fn never reaches the OS, so Fn+CapsLock is impossible;
# Shift+CapsLock is the deliberate way back to case-lock.
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

echo "Installed. Tap CapsLock = F19 (Neovim <leader>); Shift+CapsLock = real CapsLock."
echo "Rollback: restore /etc/keyd/default.conf.bak (or rm it) && systemctl restart keyd"
