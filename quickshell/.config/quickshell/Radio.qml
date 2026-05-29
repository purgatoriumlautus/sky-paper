pragma Singleton

import Quickshell
import Quickshell.Io

// rfkill state. airplaneOn = all radios soft-blocked; btOn = bluetooth radio up.
Singleton {
    id: root
    property bool airplaneOn: false
    property bool btOn: false

    function refresh() { apGet.running = true; btGet.running = true; }
    function toggleAirplane() {
        apToggle.command = ["rfkill", root.airplaneOn ? "unblock" : "block", "all"];
        apToggle.running = true;
        root.airplaneOn = !root.airplaneOn;
        // bt/wifi state re-probed next time the popup opens
    }

    Process {
        id: apGet
        // "airplane on" = no radio is unblocked
        command: ["sh", "-c", "rfkill list all -no SOFT | grep -q unblocked && echo 0 || echo 1"]
        stdout: StdioCollector { onStreamFinished: root.airplaneOn = text.trim() === "1" }
    }
    Process { id: apToggle }
    Process {
        id: btGet
        command: ["sh", "-c", "rfkill list bluetooth | grep -q 'Soft blocked: no' && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.btOn = text.trim() === "1" }
    }
}
