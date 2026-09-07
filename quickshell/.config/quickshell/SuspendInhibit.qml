pragma Singleton

import Quickshell

// State for the CC "Auto-suspend" row. `enabled` true = normal idle pipeline.
// `enabled` false = keep-awake: Bar.qml holds a Wayland idle inhibitor
// (zwp_idle_inhibit_manager_v1, which niri implements) on the bar surface, so
// niri stops reporting idle and swayidle's ENTIRE timeline pauses — dim (where
// there is a backlight), lock+screen-off, suspend. The screen simply stays on.
//
// Two earlier implementations were both wrong:
//
// 1. `systemd-inhibit --mode=block --what=sleep`. A block-mode sleep inhibitor
//    blocks every logind sleep path, lid switch included — with Auto-suspend
//    off, closing a laptop lid was a no-op and the machine stayed awake in a
//    closed bag (suspected cause of a dead battery). It also did NOT do what
//    the row implies: dim and lock+screen-off still fired on schedule, so the
//    screen went dark anyway.
// 2. A flag file gating only swayidle's 30m step. Fixed the lid bug, but still
//    let dim and lock+screen-off run.
//
// The idle inhibitor is the same mechanism mpv and fullscreen video already
// use, so keep-awake now behaves identically to "a video is playing".
//
// Deliberately NOT affected — lid close still suspends, unconditionally.
// zwp_idle_inhibit only suppresses idle notifications to swayidle; it has no
// bearing on logind's HandleLidSwitch. Shutting a lid always sleeps.
//
// No persistence and no child process: state dies with qs, so a crash fails
// safe (idle pipeline resumes) instead of leaking an inhibit that outlives the
// shell, which is how the systemd-inhibit version could silently wedge.
Singleton {
    id: root
    property bool enabled: true

    function toggle() { root.enabled = !root.enabled; }
}
