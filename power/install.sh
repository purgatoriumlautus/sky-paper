#!/usr/bin/env bash
# Install lid/sleep/hibernate policy for laniakea. Run with sudo.
#
# Why a script and not stow: /etc/systemd/ is root-owned and outside $HOME.
# Same pattern as tlp/install.sh and sysctl/install.sh.
#
# What it does:
#   - Refuses to run unless hibernation is actually viable (see below).
#   - Drops 00-aru.conf into /etc/systemd/logind.conf.d/ and sleep.conf.d/.
#   - Reloads systemd-logind so lid handling takes effect now.
#
# Why the hibernation gate: this module points lid-close at
# suspend-then-hibernate. If hibernation is broken, systemd wakes the machine
# at the HibernateDelaySec mark, fails to hibernate, and can leave it awake —
# with the lid shut. That is the exact bag-thermal failure this module exists
# to prevent, so a broken hibernate must block the install, not warn about it.
#
# Rollback: rm /etc/systemd/{logind,sleep}.conf.d/00-aru.conf
#           systemctl reload systemd-logind
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() { echo "REFUSING: $*" >&2; exit 1; }

# --- hibernation preconditions -------------------------------------------

grep -qw disk /sys/power/state \
    || fail "kernel has no hibernate support (/sys/power/state lacks 'disk')"

# resume= must resolve to a real device. /sys/power/resume is 0:0 when the
# kernel could not resolve the cmdline resume= UUID.
resume_dev="$(cat /sys/power/resume 2>/dev/null || echo 0:0)"
[[ "$resume_dev" != "0:0" ]] \
    || fail "no resume device — add resume=UUID=<swap> to the kernel cmdline
         (GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then grub-mkconfig
         -o /boot/grub/grub.cfg). Without it the image is written and never read."

# Image must fit. Compare raw totals rather than `free -h` rounding.
mem_kb="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
swap_kb="$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)"
[[ "$swap_kb" -gt 0 ]] || fail "no swap active — hibernation has nowhere to write"
if [[ "$swap_kb" -lt "$mem_kb" ]]; then
    fail "swap ${swap_kb} kB < RAM ${mem_kb} kB — image may not fit.
         Resize swap, or drop SleepOperation= to plain 'suspend' in
         etc/systemd/logind.conf.d/00-aru.conf and re-run."
fi

echo "hibernate preconditions OK (resume=$resume_dev, swap ${swap_kb} kB >= RAM ${mem_kb} kB)"

# --- install --------------------------------------------------------------

install -d -m 755 /etc/systemd/logind.conf.d /etc/systemd/sleep.conf.d
install -m 644 "$SRC/etc/systemd/logind.conf.d/00-aru.conf" /etc/systemd/logind.conf.d/00-aru.conf
install -m 644 "$SRC/etc/systemd/sleep.conf.d/00-aru.conf"  /etc/systemd/sleep.conf.d/00-aru.conf

# Hand-edited settings left in the main files still parse; drop-ins are read
# later so they win, but a stale duplicate is a trap for the next reader.
for f in /etc/systemd/logind.conf /etc/systemd/sleep.conf; do
    if grep -qE '^[[:space:]]*[A-Za-z]+=' "$f" 2>/dev/null; then
        echo "NOTE: $f has hand-edited settings:"
        grep -nE '^[[:space:]]*[A-Za-z]+=' "$f" | sed 's/^/        /'
        echo "      The drop-in overrides these, but comment them out to keep"
        echo "      this module the single source of truth."
    fi
done

# reload, not restart — restarting logind can tear down the graphical session.
systemctl reload systemd-logind

echo
echo "Installed. Spot-check:"
echo "  systemd-analyze cat-config systemd/logind.conf | grep -E '^Handle|^SleepOperation'"
echo "  systemd-analyze cat-config systemd/sleep.conf  | grep -E '^Hibernate|^MemorySleep'"
echo "  cat /sys/power/mem_sleep     # → s2idle [deep] after the next suspend"
