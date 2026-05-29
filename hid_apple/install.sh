#!/usr/bin/env bash
# Make F1-F12 work on the Epomaker x Feker Galaxy80 (X80). Run with sudo.
#
# Why a script and not stow: the fix is /etc/modprobe.d/hid_apple.conf,
# root-owned and outside $HOME — not stow-able. Same reasoning as
# keyd/install.sh and quickshell-greeter/install.sh.
#
# Why it's needed: in Mac mode the keyboard reports Apple's USB vendor id
# (05AC:024F), so hid_apple claims it and maps F1-F12 to media keys.
# fnmode=2 makes the function keys primary. See etc/modprobe.d/hid_apple.conf.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d -m 755 /etc/modprobe.d
install -m 644 "$SRC/etc/modprobe.d/hid_apple.conf" /etc/modprobe.d/hid_apple.conf

# Apply now: the modprobe.d option is only read at module load, and
# replugging the keyboard does not reload hid_apple. Poke the live param
# so F1-F12 work this boot without a reboot.
if [[ -w /sys/module/hid_apple/parameters/fnmode ]]; then
    echo 2 > /sys/module/hid_apple/parameters/fnmode
fi

# Persist across boots even if hid_apple ends up in the initramfs.
if command -v mkinitcpio >/dev/null 2>&1; then
    mkinitcpio -P
fi

echo "Installed. F1-F12 are now primary (Fn for media)."
echo "Live fnmode: $(cat /sys/module/hid_apple/parameters/fnmode 2>/dev/null)"
echo "Rollback: rm /etc/modprobe.d/hid_apple.conf && echo 3 > /sys/module/hid_apple/parameters/fnmode"
