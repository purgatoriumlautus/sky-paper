#!/usr/bin/env bash
# Install the weekly restic backup timer. Run with sudo.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f /root/.restic-pass ]];
  then echo "missing /root/.restic-pass" >&2;
    exit 1;
fi

# warning about permissions
if [[ $(stat -c %a /root/.restic-pass) != 600 ]];
  then echo "warning .restic-pass permissions arent 600";
    chmod 600 /root/.restic-pass
fi

if ! grep -qs '^Host storagebox' /root/.ssh/config;
  then echo 'pls add storagebox to /root/.ssh/config';exit 1;
fi

install -m 644 "$SRC/etc/systemd/system/restic-backup.timer" /etc/systemd/system/restic-backup.timer
install -m 644 "$SRC/etc/systemd/system/restic-backup.service" /etc/systemd/system/restic-backup.service

# Reminder runs in the session, so it is a user unit — /etc/systemd/user is the
# root-installable location for those.
install -d -m 755 /etc/systemd/user
install -m 644 "$SRC/etc/systemd/user/restic-reminder.service" /etc/systemd/user/restic-reminder.service
install -m 644 "$SRC/etc/systemd/user/restic-reminder.timer" /etc/systemd/user/restic-reminder.timer

systemctl daemon-reload
systemctl enable --now restic-backup.timer
systemctl --global enable restic-reminder.timer

echo "Installed."
cat <<'EOF'
Finish as segfault (--global only takes effect for the running user manager after a reload):
systemctl --user daemon-reload
systemctl --user start restic-reminder.timer

Rollback:
sudo systemctl disable --now restic-backup.timer
sudo systemctl --global disable restic-reminder.timer
systemctl --user stop restic-reminder.timer
sudo rm /etc/systemd/system/restic-backup.timer
sudo rm /etc/systemd/system/restic-backup.service
sudo rm /etc/systemd/user/restic-reminder.timer
sudo rm /etc/systemd/user/restic-reminder.service
sudo systemctl daemon-reload
EOF
