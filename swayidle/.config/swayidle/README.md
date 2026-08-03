# swayidle — idle pipeline

The idle daemon for laniakea (niri session). Watches "seconds since last
input" and fires actions on a timeline. Started by niri:
`spawn-at-startup "swayidle" "-w"` (niri restarts it if it dies).

Stow package → `~/.config/swayidle/config`.

## Timeline

| idle | action | undo on activity |
|---|---|---|
| 5 min | dim: `brightnessctl --save && set 50%-` | `brightnessctl --restore` |
| 10 min | `qs ipc call lock lock` **then** `niri msg action power-off-monitors` | `power-on-monitors` (lock stays) |
| 30 min | `systemctl suspend` | — (logind/swayidle re-init on wake) |

Plus always-on hooks:

- `before-sleep 'qs ipc call lock lock'` — locks **before** any suspend
  (idle, lid, manual), so wake shows the lock screen with no flash of the
  desktop.
- `lock 'qs ipc call lock lock'` — `loginctl lock-session` is broadcast by
  logind, swayidle's `lock` handler runs the IPC call, the Quickshell
  `LockScreen` (`~/.config/quickshell/LockScreen.qml`) maps a `WlSessionLock`
  surface and PAM-authenticates the user.

## Design notes

- **Same timings on AC and battery** — chosen deliberately; battery saving
  is the priority, no AC/battery split.
- **Lock + screen-off in the same 10m step** — locking later than screen-off
  would leave a window where the screen is dark but unlocked (a mouse nudge
  shows the desktop). Lock paints first so there's no bare-desktop frame.
- **Auto-suspend is toggleable** from the Quickshell control center
  ("Auto-suspend" row). Off → `Bar.qml` holds a Wayland idle inhibitor
  (`IdleInhibitor`, zwp_idle_inhibit) on the bar surface, niri stops reporting
  idle, and **this entire timeline pauses** — no dim, no lock, no screen-off,
  no suspend. Same mechanism fullscreen video already uses. State lives only in
  the qs process, so a crash fails safe (pipeline resumes).
- **Lid close is never inhibited.** zwp_idle_inhibit only suppresses idle
  notifications to swayidle; logind's `HandleLidSwitch` is untouched, so
  shutting the lid always sleeps. This matters: the toggle used to be a
  `systemd-inhibit --mode=block --what=sleep` process, which blocked *every*
  logind sleep path — with auto-suspend off, closing the lid did nothing and
  the machine stayed awake in a closed bag (suspected cause of the previous
  battery's death). See `power/README.md`.
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
