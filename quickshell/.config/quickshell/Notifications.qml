pragma Singleton

import Quickshell
import Quickshell.Io

// mako DND state. dnd=true → mode=do-not-disturb (popups suppressed; history
// still accrues). Same shape as Radio.qml / SuspendInhibit.qml: re-probe on CC
// open, no periodic polling. `toggle` is optimistic; next `refresh` corrects
// if makoctl wasn't running.
Singleton {
    id: root
    property bool dnd: false

    function refresh() { modeGet.running = true; }
    function toggle() {
        modeToggle.command = ["makoctl", "mode", "-t", "do-not-disturb"];
        modeToggle.running = true;
        root.dnd = !root.dnd;
    }

    Process {
        id: modeGet
        command: ["sh", "-c", "makoctl mode 2>/dev/null | grep -q do-not-disturb && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.dnd = text.trim() === "1" }
    }
    Process { id: modeToggle }
}
