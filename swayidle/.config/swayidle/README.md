# swayidle — idle pipeline

The idle daemon for this machine (niri session). Watches "seconds since last
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

- **No dim step** — the one delta vs the laptop config: this is a desktop
  with external monitors, so there is no backlight for `brightnessctl` to dim.
- **Lock + screen-off in the same 10m step** — locking later than screen-off
  would leave a window where the screen is dark but unlocked (a mouse nudge
  shows the desktop). Lock paints first so there's no bare-desktop frame.
- **Auto-suspend is toggleable** from the Quickshell control center
  ("Auto-suspend" row). Off → `Bar.qml` holds a Wayland idle inhibitor
  (`IdleInhibitor`, zwp_idle_inhibit) on the bar surface, niri stops reporting
  idle, and **this entire timeline pauses** — no lock, no screen-off,
  no suspend. Same mechanism fullscreen video already uses. State lives only in
  the qs process, so a crash fails safe (pipeline resumes).
- **Why not `systemd-inhibit`.** The toggle used to be a
  `systemd-inhibit --mode=block --what=sleep` process. It blocked *every*
  logind sleep path (on a laptop that meant a closed lid did nothing and the
  machine cooked in a bag), and it did not actually keep the screen on — lock
  and screen-off still fired on schedule. zwp_idle_inhibit suppresses only the
  idle notifications swayidle listens to, so it pauses the timeline and leaves
  logind alone.
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
