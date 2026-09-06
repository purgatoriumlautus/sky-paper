# restic — weekly whole-system backup

| Unit | Job |
|---|---|
| `restic-backup.service` | One-shot snapshot of `/` into `sftp:storagebox:restic`, then `forget --prune`. |
| `restic-backup.timer` | Sundays 03:00, `Persistent=true`, jittered up to 1h so the Storage Box isn't hit by every machine at once. |

Retention: 8 weekly + 12 monthly snapshots, pruned in the same run
(`ExecStartPost`). Roughly two months of week-granular history plus a year of
month-granular history.

Excluded: pseudo-filesystems (`/dev`, `/proc`, `/sys`, `/run`), scratch
(`/tmp`, `/var/tmp`), the pacman package cache and sync DBs, every user's
`~/.cache`, `~/archive` (that *is* the Storage Box — backing it up into
itself would be circular), and `/mnt` + `/media`.

## Prerequisites (neither is tracked here — both live in /root)

- `/root/.restic-pass` — the repository password, mode 600, root-owned. Lose
  it and the backup is unrecoverable; restic has no recovery path.
- `/root/.ssh/config` with a `storagebox` host alias plus its key. The
  repository URL `sftp:storagebox:restic` is restic's own sftp backend
  resolving that alias — it does **not** go through rclone. `rclone/` and
  this module reach the same box through separate, independent credentials.

## Install

```sh
sudo ./install.sh
```

## Verify

```sh
systemctl is-enabled restic-backup.timer
systemctl list-timers restic-backup.timer
sudo systemctl start restic-backup && journalctl -u restic-backup -f
```

## Restore

```sh
sudo -i
export RESTIC_REPOSITORY=sftp:storagebox:restic RESTIC_PASSWORD_FILE=/root/.restic-pass
restic snapshots                        # pick an ID
restic restore <ID> --target /mnt/restore --include /home/aru/<path>
```

Restore to a scratch target and copy back by hand. Never restore over a live
`/`.

## Known gap: --one-file-system

The backup crosses no filesystem boundaries, so anything on its own partition
is silently absent from the snapshot. Confirm what that covers here:

```sh
findmnt -t ext4,btrfs,xfs,vfat
```

If `/home` turns out to be a separate partition, it is **not** in the weekly
backup and the unit needs a second path argument.

## Rollback

```sh
sudo systemctl disable --now restic-backup.timer
sudo rm /etc/systemd/system/restic-backup.{service,timer}
sudo systemctl daemon-reload
```

Removing the units leaves the remote repository untouched.

