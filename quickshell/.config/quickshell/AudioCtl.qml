pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Pipewire audio-output backend. Lists selectable sinks and switches the
// default. Mirrors WifiCtl/BtCtl so ControlCenter treats all three rows
// the same — but audio has no daemon to poke: Pipewire is always live, so
// there is no power toggle and no scan (the list is a reactive binding).
Singleton {
    id: root

    // Hardware / virtual output devices. Exclude application playback
    // streams (isStream) and inputs (isSink === false). `.values` is the
    // reactive view of the node model — model[i] would not update.
    readonly property var sinks:
        Pipewire.nodes.values.filter(function (n) {
            return n && n.isSink && !n.isStream && n.audio;
        })
    // the sink pipewire actually routes to (briefly null while switching)
    readonly property var currentSink: Pipewire.defaultAudioSink

    function label(n) {
        if (!n) return "—";
        return n.description || n.nickname || n.name || "?";
    }
    function setSink(n) {
        // a hint to pipewire; defaultAudioSink follows when possible
        if (n) Pipewire.preferredDefaultAudioSink = n;
    }

    // Pipewire nodes are unbound by default — description/nickname stay
    // empty until tracked. Bind every sink so the picker shows real names
    // and they stay live.
    PwObjectTracker { objects: root.sinks }
}
