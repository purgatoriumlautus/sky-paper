# swayidle — idle pipeline

The idle daemon for celestia (niri session). Watches "seconds since last
input" and fires actions on a timeline. Started by niri:
`spawn-at-startup "swayidle" "-w"` (niri restarts it if it dies).

Stow package → `~/.config/swayidle/config`.

## Timeline

| idle | action | undo on activity |
|---|---|---|
| 10 min | `qs ipc call lock lock` **then** `niri msg action power-off-monitors` | `power-on-monitors` (lock stays) |
| 30 min | `systemctl suspend` | — (logind/swayidle re-init on wake) |

Plus always-on hooks:

- `before-sleep 'qs ipc call lock lock'` — locks **before** any suspend
  (idle or manual), so wake shows the lock screen with no flash of the
  desktop.
- `lock 'qs ipc call lock lock'` — `loginctl lock-session` is broadcast by
  logind, swayidle's `lock` handler runs the IPC call, the Quickshell
  `LockScreen` (`~/.config/quickshell/LockScreen.qml`) maps a `WlSessionLock`
  surface and PAM-authenticates the user.

## Design notes

- **No dim step** — the one delta vs the laptop config: celestia is a
  desktop with external monitors; there is no backlight for `brightnessctl`
  to dim.
- **Lock + screen-off in the same 10m step** — locking later than screen-off
  would leave a window where the screen is dark but unlocked (a mouse nudge
  shows the desktop). Lock paints first so there's no bare-desktop frame.
- **Auto-suspend is toggleable** from the Quickshell control center
  ("Auto-suspend" row). Off → a `systemd-inhibit --mode=block --what=sleep`
  process blocks the 30m suspend; lock + screen-off still work — they don't
  go through logind sleep. Session-scoped, resets to on each login.
- **Video**: mpv / fullscreen browser video hold a wayland idle-inhibitor,
  so the timeline pauses. Small windowed browser video may not — known
  limitation, use fullscreen.

## Gotcha

swayidle has **no `\` line continuation**. Each `timeout … resume …`
directive must be on one physical line — a backslash gives
`wordexp syntax error` and swayidle refuses to start.

## Verify

```sh
pgrep -a swayidle                       # one process with -w
swayidle -w -C ~/.config/swayidle/config   # Ctrl-C; errors print on parse
```
