#!/usr/bin/env bash
# Install the sysctl hardening drop-in. Run with sudo.
#
# Why a script and not stow: /etc/sysctl.d/ is root-owned and outside $HOME.
# Same pattern as nftables/install.sh and sshd/install.sh.
#
# What it does:
#   - Drops 99-hardening.conf into /etc/sysctl.d/.
#   - Applies it immediately via `sysctl --system` (no reboot needed).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d -m 755 /etc/sysctl.d
install -m 644 "$SRC/etc/sysctl.d/99-hardening.conf" /etc/sysctl.d/99-hardening.conf

# Reload all sysctl.d/ drop-ins so the values take effect now
sysctl --system >/dev/null

echo "Installed. Spot-check: sysctl kernel.kptr_restrict net.ipv4.conf.all.rp_filter"
echo "Rollback: rm /etc/sysctl.d/99-hardening.conf && sysctl --system"
