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

systemctl daemon-reload
systemctl enable --now restic-backup.timer

echo "Installed."
cat <<'EOF'
Rollback:
sudo systemctl disable --now restic-backup.timer
sudo rm /etc/systemd/system/restic-backup.timer
sudo rm /etc/systemd/system/restic-backup.service
sudo systemctl daemon-reload
EOF

