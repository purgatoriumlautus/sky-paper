# rclone — Storage Box mount + two-way sync

Two independent jobs against one Hetzner Storage Box (`storagebox:`), both
running as **system** units under `User=segfault`:

| Unit | Job |
|---|---|
| `rclone-archive.service` | FUSE-mounts `storagebox:archive` at `~/archive`. VFS cache in full mode, capped at 5G, directory listings cached 24h. |
| `rclone-sync.service` | One-shot `rclone bisync` between `~/cloud` and `storagebox:sync`. `static` — never enabled directly, the timer pulls it. |
| `rclone-sync.timer` | Fires 2 min after boot, then every 15 min. `Persistent=true` catches up a run missed while powered off. |

## Why system units and not user units

A user unit only lives inside a login session, and the user manager has no
`network-online.target` — an `After=` on it there is silently ignored
(`systemctl --user list-units --all` shows it as `not-found`). As system
units these sync on an unattended machine and order against the real target.

The cost is that `%h` is unusable: in a system unit it expands to the
*manager's* home (`/root`), regardless of `User=`. Every home path here is
therefore absolute, and `Environment=HOME=` is set explicitly so rclone
resolves the `~` inside `rclone.conf`.

## Prerequisites (none of them tracked here)

- `~/.config/rclone/rclone.conf` with a `[storagebox]` sftp remote — see
  `rclone.conf.example` for its shape, or recreate with `rclone config`.
- The ssh private key that `key_file` points at, registered on the Storage
  Box, plus its `known_hosts` entry.

## Migrating off the old user units

The units used to live in `~/.config/systemd/user/`. Leaving them enabled
alongside the system ones means two processes on one mountpoint and two
bisync runs contending for one lock pair, so tear them down **first**:

```sh
systemctl --user disable --now rclone-archive.service rclone-sync.timer
rm ~/.config/systemd/user/rclone-{archive.service,sync.service,sync.timer}
systemctl --user daemon-reload
```

`install.sh` refuses to run while those files are still present.

## Install

```sh
sudo ./install.sh
```

## Verify

```sh
systemctl is-enabled rclone-archive rclone-sync.timer
findmnt ~/archive
systemctl list-timers rclone-sync.timer
```

`findmnt` should report an `rclone` fuse mount; files under `~/archive` and
`~/cloud` must be owned by `segfault`, not `root`.

## Known gap: bisync state

`rclone bisync` keeps the previous run's listings in `~/.cache/rclone/bisync/`.
If that state is missing — fresh machine, cleared cache, first ever run — the
command aborts and asks for `--resync`, which picks one side as authoritative
and overwrites the other. Run it by hand, deliberately, choosing the direction:

```sh
rclone bisync ~/cloud storagebox:sync --resync
```

The timer has no failure notification, so a broken bisync fails quietly every
15 min. Check `systemctl status rclone-sync` if `~/cloud` stops updating.

## Rollback

```sh
sudo systemctl disable --now rclone-archive rclone-sync.timer
sudo rm /etc/systemd/system/rclone-{archive.service,sync.service,sync.timer}
sudo systemctl daemon-reload
```
