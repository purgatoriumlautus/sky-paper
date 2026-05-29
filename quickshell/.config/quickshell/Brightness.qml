pragma Singleton

import Quickshell
import Quickshell.Io

// Backlight via brightnessctl. value is 0–100.
Singleton {
    id: root
    property int value: 0

    function refresh() { getProc.running = true; }
    function set(v) {
        v = Math.max(1, Math.min(100, Math.round(v)));
        root.value = v;
        setProc.command = ["brightnessctl", "set", v + "%"];
        setProc.running = true;
    }

    Process {
        id: getProc
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: { var n = parseInt(text); if (!isNaN(n)) root.value = n; }
        }
    }
    Process { id: setProc }
}
