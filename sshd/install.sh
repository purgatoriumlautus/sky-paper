#!/usr/bin/env bash
# Install the sshd hardening drop-in. Run with sudo.
#
# Why a script and not stow: /etc/ssh/sshd_config.d/ is root-owned and
# outside $HOME — not stow-able. Same reasoning as keyd/install.sh.
#
# What it does:
#   - Drops 00-hardening.conf into /etc/ssh/sshd_config.d/.
#   - Verifies the main sshd_config includes that directory.
#   - sshd -t syntax check, then reload (existing sessions survive).
#
# Lockout warning: this disables PasswordAuthentication. If sshd is reachable
# from elsewhere, make sure ~/.ssh/authorized_keys is populated BEFORE running
# this on that host.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Sanity-check the include line exists (Arch default has it, but be sure)
if ! grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
    echo "warning: /etc/ssh/sshd_config has no Include for sshd_config.d/*.conf;" >&2
    echo "         the drop-in will be ignored until you add that line." >&2
fi

# 2. Install the drop-in
install -d -m 755 /etc/ssh/sshd_config.d
install -m 644 "$SRC/etc/ssh/sshd_config.d/00-hardening.conf" \
    /etc/ssh/sshd_config.d/00-hardening.conf

# Remove the old name of this drop-in, if a previous install left it behind
rm -f /etc/ssh/sshd_config.d/99-hardening.conf

# 3. Validate + reload
if ! sshd -t; then
    echo "sshd -t failed; not reloading" >&2
    exit 1
fi
systemctl reload sshd

echo "Installed. Verify effective config: sshd -T | grep -iE 'passwordauth|permitroot|x11forward'"
echo "Rollback: rm /etc/ssh/sshd_config.d/00-hardening.conf && systemctl reload sshd"
