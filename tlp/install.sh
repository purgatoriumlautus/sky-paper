#!/usr/bin/env bash
# Install TLP overrides for laniakea. Run with sudo.
#
# Why a script and not stow: /etc/tlp.d/ is root-owned and outside $HOME.
# Same pattern as keyd/install.sh, sysctl/install.sh, nftables/install.sh.
#
# What it does:
#   - Ensures tlp, tlp-rdw, smartmontools are installed.
#   - Drops 00-aru.conf into /etc/tlp.d/.
#   - Enables tlp.service (idempotent) and runs `tlp start` to apply now.
#
# Revert just the thresholds: rm /etc/tlp.d/00-aru.conf && tlp start
# (TLP itself was already enabled before this script; leave it alone.)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pacman -S --needed tlp tlp-rdw smartmontools

install -d -m 755 /etc/tlp.d
install -m 644 "$SRC/etc/tlp.d/00-aru.conf" /etc/tlp.d/00-aru.conf

systemctl enable --now tlp.service
# Re-read /etc/tlp.d/ — enable --now is a no-op when service is already
# running, so re-runs after editing the conf won't pick up changes
# without this.
tlp start

echo "Installed. Spot-check:"
echo "  cat /sys/class/power_supply/BAT0/charge_control_start_threshold  # → 85"
echo "  cat /sys/class/power_supply/BAT0/charge_control_end_threshold    # → 90"
