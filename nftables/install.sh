#!/usr/bin/env bash
# Install the nftables firewall. Run with sudo.
#
# Why a script and not stow: /etc/nftables.conf and /etc/nftables.d/ are
# root-owned and outside $HOME — not stow-able. Same reasoning as
# keyd/install.sh and quickshell-greeter/install.sh.
#
# What it does:
#   - Backs up any existing /etc/nftables.conf once.
#   - Installs the entry point (just flush + include) and one rule file
#     under /etc/nftables.d/.
#   - Validates the resulting ruleset before reloading the service.
#
# Layout rationale: the entry point flushes and includes; real rules live
# in /etc/nftables.d/*.nft so you can drop in extra files (e.g. wireguard,
# specific port allows) without editing the main config.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Back up the existing entry point once
[[ -f /etc/nftables.conf && ! -f /etc/nftables.conf.bak ]] \
    && cp /etc/nftables.conf /etc/nftables.conf.bak

# 2. Install entry point + rule drop-ins
install -m 644 "$SRC/etc/nftables.conf" /etc/nftables.conf
install -d -m 755 /etc/nftables.d
install -m 644 "$SRC"/etc/nftables.d/*.nft /etc/nftables.d/

# 3. Validate the merged ruleset before touching the live firewall
if ! nft -c -f /etc/nftables.conf; then
    echo "nft syntax check failed; not enabling service" >&2
    exit 1
fi

# 4. Enable + load
# The unit is Type=oneshot with no ExecReload: `systemctl reload` is not a
# valid job for it. `enable --now` loads the ruleset; restart re-loads it.
systemctl enable --now nftables

echo "Installed. Live ruleset: nft list ruleset"
echo "Rollback: cp /etc/nftables.conf.bak /etc/nftables.conf && systemctl restart nftables"
