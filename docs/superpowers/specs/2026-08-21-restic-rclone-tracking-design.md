# restic + rclone → tracked modules

Date: 2026-08-21
Status: approved design, not yet implemented

## Goal

Bring the existing, already-working backup and cloud setup under repo
control as two `install.sh` modules, and fix the defects found while
reading the live units.

Live state today (source of truth until migration):

| unit | manager | file |
| --- | --- | --- |
| `rclone-archive.service` | user | `~/.config/systemd/user/` |
| `rclone-sync.service` | user | `~/.config/systemd/user/` |
| `rclone-sync.timer` | user | `~/.config/systemd/user/` |
| `restic-backup.service` | system | `/etc/systemd/system/` |
| `restic-backup.timer` | system | `/etc/systemd/system/` |

What they do: `rclone-archive` FUSE-mounts `storagebox:archive` at
`~/archive` (vfs-cache full, 5G cap). `rclone-sync` runs `rclone bisync`
between `~/cloud` and `storagebox:sync` every 15 min. `restic-backup`
takes a weekly `/`-wide snapshot to `sftp:storagebox:restic`, then
`forget --keep-weekly 8 --keep-monthly 12 --prune`.

## Decisions

1. **Two modules, not one.** `rclone/` and `restic/`, matching the
   repo's one-tool-one-module rule. They share only the Storage Box
   endpoint; lifecycles are independent.
2. **Both are `install.sh` modules, neither is stowed.** All five units
   move to `/etc/systemd/system/`.
3. **rclone moves from the user manager to the system manager.** Reason:
   a system unit runs at boot regardless of login, so bisync ticks on an
   unattended machine — and `network-online.target` exists there, which
   it does not in the user manager.
4. **Secrets stay out of the repo.** `rclone.conf` is never tracked;
   `rclone/rclone.conf.example` documents its shape with placeholders.
   `/root/.restic-pass` is only checked for, never created or read by
   `install.sh`.

## Module layout

```
rclone/
  etc/systemd/system/{rclone-archive.service,rclone-sync.service,rclone-sync.timer}
  rclone.conf.example
  install.sh
  README.md
restic/
  etc/systemd/system/{restic-backup.service,restic-backup.timer}
  install.sh
  README.md
```

`install.sh` follows `keyd/install.sh`: `set -euo pipefail`, EUID check,
`SRC` resolved from `BASH_SOURCE`, `install -m 644` per file, then
`daemon-reload` + `enable --now`, closing with an echoed rollback line.

## Unit changes

### Both modules

- `Wants=network-online.target` alongside the existing `After=`. `After=`
  orders only; without `Wants=` nothing pulls the target in.

### rclone units — system-manager conversion

- `User=` / `Group=` set to the desktop user. Without it everything runs
  as root: the FUSE mount would need `--allow-other` plus an
  `/etc/fuse.conf` edit, and `~/cloud` would fill with root-owned files.
- Every `%h` replaced with a hardcoded home path. In a system unit `%h`
  resolves to the *manager's* home (`/root`) and is not influenced by
  `User=` — left as-is, the Storage Box would mount at `/root/archive`.
  Three call sites: the mount target, the bisync local path, the
  `ExecStop` path.
- `HOME` supplied via `Environment=` so rclone finds
  `~/.config/rclone/rclone.conf`, mirroring `Environment=HOME=/root` in
  `restic-backup.service`.
- `WantedBy=multi-user.target` replaces `default.target`.
- **Fix:** `ExecStop` in `rclone-archive.service` unmounts `%h/mnt/box`
  while `ExecStart` mounts `%h/archive` — a stale path from an earlier
  config. Today the stop action fails and the mount is left behind.

### Deferred, not in this change

Reviewed and consciously left alone; revisit separately:

- `rclone bisync` fails hard when its listing state in
  `~/.cache/rclone/bisync/` is missing (fresh machine, cleared cache, no
  prior `--resync`). The timer would keep firing into a failing oneshot
  with no notification.
- `restic backup / --one-file-system` skips any separate mount, so a
  `/home` on its own partition would not be in the weekly snapshot.
  Needs `findmnt` confirmation of the actual layout.

## Migration

The three user units are currently `enabled` and must be torn down
before the system units are installed — otherwise two rclone processes
target one mountpoint and two bisync runs contend for one lock pair.

Order: `systemctl --user disable --now` all three → remove the files from
`~/.config/systemd/user/` → `systemctl --user daemon-reload` → run
`rclone/install.sh`. `install.sh` refuses to proceed while any of the
three user units is still enabled; the README documents the teardown.

`restic` needs no migration — it is already a system unit and the files
are copied over themselves.

## Repo bookkeeping

- `packages.txt`: `restic` and `rclone` are missing (existing drift).
  Add in the same sitting, per CONTEXT §META.
- CONTEXT.md §3 stack map: one line per new module, under the
  `install.sh` group.
- CONTEXT.md §META budget check: stack map is ~1 line per module, so +2
  lines is within budget.

## Verification

- `systemctl is-enabled rclone-archive rclone-sync.timer restic-backup.timer`
- `systemctl --user list-unit-files | grep -E 'rclone|restic'` → empty
- `findmnt ~/archive` → an `rclone` fuse mount owned by the user
- `systemctl show rclone-archive -p User -p Environment` → the desktop
  user, `HOME` pointing at their home
- `systemctl list-timers rclone-sync.timer restic-backup.timer`
- Repo grep for the Storage Box hostname and for `pass =` → no hits
  outside `rclone.conf.example` placeholders
