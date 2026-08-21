#!/usr/bin/env bash
# Install rclone fuse mounts
# 
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -e /home/segfault/.config/systemd/user/rclone-archive.service || -e /home/segfault/.config/systemd/user/rclone-sync.service || -e /home/segfault/.config/systemd/user/rclone-sync.timer ]]; 
  then echo "turn off user units for rclone" >&2;
    exit 1;
fi

install -m 644 "$SRC/etc/systemd/system/rclone-archive.service" /etc/systemd/system/rclone-archive.service
install -m 644 "$SRC/etc/systemd/system/rclone-sync.timer" /etc/systemd/system/rclone-sync.timer
install -m 644 "$SRC/etc/systemd/system/rclone-sync.service" /etc/systemd/system/rclone-sync.service

systemctl daemon-reload
systemctl enable --now rclone-archive.service
systemctl enable --now rclone-sync.timer

echo "Installed."
cat <<'EOF' 
Rollback:
sudo systemctl disable --now rclone-archive.service 
sudo systemctl disable --now rclone-sync.timer 
sudo rm /etc/systemd/system/rclone-sync.timer 
sudo rm /etc/systemd/system/rclone-archive.service 
sudo rm /etc/systemd/system/rclone-sync.service 
sudo systemctl daemon-reload
EOF

