# restic — weekly whole-system backup

| Unit | Job |
|---|---|
| `restic-backup.service` | One-shot snapshot of `/` into `sftp:storagebox:restic`, then `forget --prune`. |
| `restic-backup.timer` | Sundays 03:00, `Persistent=true`, jittered up to 1h so the Storage Box isn't hit by every machine at once. |
| `restic-reminder.service` + `.timer` | **User** units. Sundays 12:00, `Persistent=true`. Notifies if the last successful backup is older than 7 days. |

Retention: 8 weekly + 12 monthly snapshots, pruned in the same run
(`ExecStartPost`). Roughly two months of week-granular history plus a year of
month-granular history.

Excluded: pseudo-filesystems (`/dev`, `/proc`, `/sys`, `/run`), scratch
(`/tmp`, `/var/tmp`), the pacman package cache and sync DBs, every user's
`~/.cache`, `~/archive` (that *is* the Storage Box — backing it up into
itself would be circular), and `/mnt` + `/media`.

## Metered connections

A weekly run over a phone hotspot is not something to discover from the data
bill, so the service carries an `ExecCondition=`:

```
ExecCondition=/usr/bin/bash -c '! nmcli -t -f METERED general | grep -q "^yes"'
```

NetworkManager's global `METERED` reflects the connection carrying the default
route. Non-zero from an `ExecCondition=` makes systemd **skip** the unit — it
is not marked failed, and the timer fires again next week as usual.

The catch: NM only *guesses*. A phone hotspot normally reports `no (guessed)`
and would be backed up over. Mark it once, by hand, and the flag sticks in the
connection profile:

```sh
nmcli connection modify <hotspot> connection.metered yes
nmcli -t -f METERED general      # yes, while connected to it
```

`unknown` and both `(guessed)` values are treated as "go ahead" — the check
only stops on an explicit or guessed **yes**.

## The reminder

A skipped run leaves no snapshot, so `restic-backup.service` stamps
`/var/lib/restic-last-backup` in a second `ExecStartPost=` — after `forget
--prune` succeeded, so the stamp means the whole run went through. The user
timer reads that file's mtime and nothing else: no root, no network, no
traffic. Older than 7 days (or missing) and mako gets

> **Пора сделать бекап** — Последний: 29 Aug — sudo systemctl start restic-backup

It is a plain notification with no action button: without a polkit agent in the
session a button could not raise the privileges anyway, so the command is in
the body to be typed.

Why a user unit: `notify-send` needs the session bus, which the system manager
has no route to. It is installed to `/etc/systemd/user/` (root-writable,
visible to every user manager) and turned on with `systemctl --global enable`.

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
systemctl --user daemon-reload            # as aru, picks up the --global enable
systemctl --user start restic-reminder.timer
```

`--global enable` only writes the symlink; a user manager that is already
running needs the reload to see it. `install.sh` prints both lines too.

## Verify

```sh
systemctl is-enabled restic-backup.timer
systemctl list-timers restic-backup.timer
sudo systemctl start restic-backup && journalctl -u restic-backup -f

systemctl --user list-timers restic-reminder.timer
systemctl --user start restic-reminder.service   # notifies iff the stamp is stale
stat -c %y /var/lib/restic-last-backup
```

To see the reminder regardless of the stamp, age it:
`sudo touch -d '9 days ago' /var/lib/restic-last-backup`.

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
sudo systemctl --global disable restic-reminder.timer
systemctl --user stop restic-reminder.timer
sudo rm /etc/systemd/system/restic-backup.{service,timer}
sudo rm /etc/systemd/user/restic-reminder.{service,timer}
sudo systemctl daemon-reload
```

Removing the units leaves the remote repository untouched.
