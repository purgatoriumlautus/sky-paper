# swayidle — idle pipeline

The idle daemon for celestia (niri session). Watches "seconds since last
input" and fires actions on a timeline. Started by niri:
`spawn-at-startup "swayidle" "-w"` (niri restarts it if it dies).

Stow package → `~/.config/swayidle/config`.

## Timeline

One idle step — that's the whole timeline:

| idle | action | undo on activity |
|---|---|---|
| 10 min | `qs ipc call lock lock` **then** `niri msg action power-off-monitors` | `power-on-monitors` (lock stays) |

Plus always-on hooks:

- `before-sleep 'qs ipc call lock lock'` — locks **before** any manual
  suspend, so wake shows the lock screen with no flash of the desktop.
- `lock 'qs ipc call lock lock'` — `loginctl lock-session` is broadcast by
  logind, swayidle's `lock` handler runs the IPC call, the Quickshell
  `LockScreen` (`~/.config/quickshell/LockScreen.qml`) maps a `WlSessionLock`
  surface and PAM-authenticates the user.

## Design notes

Deliberate deltas vs the laptop config:

- **No dim step** — celestia is a desktop with external monitors; there is
  no backlight for `brightnessctl` to dim.
- **No auto-suspend** — deliberate for a desktop; it stays up. Suspend only
  happens manually (covered by the `before-sleep` hook above).
- **Lock + screen-off in the same 10m step** — locking later than screen-off
  would leave a window where the screen is dark but unlocked (a mouse nudge
  shows the desktop). Lock paints first so there's no bare-desktop frame.

## Gotcha

swayidle has **no `\` line continuation**. Each `timeout … resume …`
directive must be on one physical line — a backslash gives
`wordexp syntax error` and swayidle refuses to start.

## Verify

```sh
pgrep -a swayidle                       # one process with -w
swayidle -w -C ~/.config/swayidle/config   # Ctrl-C; errors print on parse
```
