pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU energy_performance_preference cycler. 4 modes, debounced.
//
// PowerRow binds to `mode` (the visible label flips instantly on every
// cycle). The actual /sys write is deferred 1500 ms via applyTimer so
// mashing L L L from Performance to Power Save issues one pkexec, not
// three. The write is done by /usr/local/bin/set-epp via pkexec — see
// epp-toggle.rules for the polkit pass-through.
Singleton {
    id: root

    // 0=Performance, 1=Balanced (perf), 2=Balanced (save), 3=Power Save
    property int mode: 1

    readonly property var eppValues: [
        "performance",
        "balance_performance",
        "balance_power",
        "power"
    ]
    readonly property var labels: [
        "Performance",
        "Balanced (perf)",
        "Balanced (save)",
        "Power Save"
    ]

    function refresh() { getProc.running = true; }

    function cycle(dir) {
        root.mode = (root.mode + dir + 4) % 4;
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 1500
        repeat: false
        onTriggered: {
            setProc.command = ["pkexec", "/usr/local/bin/set-epp", root.eppValues[root.mode]];
            setProc.running = true;
        }
    }

    Process {
        id: getProc
        command: ["cat", "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim();
                var idx = root.eppValues.indexOf(v);
                // unknown / "default" → Balanced (perf)
                root.mode = idx >= 0 ? idx : 1;
            }
        }
    }
    Process {
        id: setProc
        onExited: (exitCode) => {
            // pkexec denied / set-epp missing / etc. Resync the label
            // from /sys so the row doesn't lie.
            if (exitCode !== 0) root.refresh();
        }
    }
}
