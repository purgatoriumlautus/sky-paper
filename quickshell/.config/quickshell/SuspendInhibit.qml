pragma Singleton

import Quickshell
import Quickshell.Io

// User-controlled inhibit on systemd "sleep". When `enabled` is false,
// `systemd-inhibit --mode=block --what=sleep` is running and `systemctl
// suspend` (from swayidle's 30m timer or lid close) is a no-op.
// Lock + screen-off keep working — they don't go through logind sleep.
// Session-scoped (not persisted): every login starts with enabled=true.
//
// Cleanup: when this Singleton destructs (qs exit) or running flips to
// false, Quickshell SIGTERMs the inhibit process, which releases the
// lock. SIGKILL leak: the systemd-inhibit child is reparented to init
// and the lock stays — `ps -ef | grep systemd-inhibit` + manual kill.
Singleton {
    id: root
    property bool enabled: true

    function toggle() {
        root.enabled = !root.enabled;
        inhibitor.running = !root.enabled;
    }

    Process {
        id: inhibitor
        running: false
        command: ["systemd-inhibit",
                  "--mode=block",
                  "--what=sleep",
                  "--who=controlcenter",
                  "--why=manual inhibit",
                  "sleep", "infinity"]
    }
}
