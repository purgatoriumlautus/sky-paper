pragma Singleton

import Quickshell
import Quickshell.Io

// Warm screen tint via wlsunset, fixed ~5500K ("¼" warmth, daytime-friendly).
Singleton {
    id: root
    property bool on: false

    function refresh() { getProc.running = true; }
    function toggle() {
        if (root.on) stopProc.running = true;
        else         startProc.running = true;
        root.on = !root.on;
    }

    Process {
        id: getProc
        command: ["sh", "-c", "pgrep -x wlsunset >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.on = text.trim() === "1" }
    }
    // Separate start/stop processes: wlsunset is a long-running daemon, so a
    // single reused Process would stay "running" forever and silently drop the
    // next .running = true. wlsunset also insists high > low temp (equal temps
    // error out silently), hence the 1-degree gap. setsid -f detaches it so
    // the start Process returns immediately.
    Process {
        id: startProc
        command: ["sh", "-c", "setsid -f wlsunset -T 5500 -t 5499 >/dev/null 2>&1"]
    }
    Process { id: stopProc; command: ["pkill", "-x", "wlsunset"] }
}
