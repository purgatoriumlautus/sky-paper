pragma Singleton

import QtQuick
import Quickshell

// Sky Paper — greeter copy. Mirrors ~/celestia/quickshell/.config/quickshell/Theme.qml.
// Separate file because greeter runs as `greeter` user and can't traverse /home/segfault (mode 700).
// If you re-tone the main palette, update this too.
Singleton {
    readonly property color bg:         "#F0EBE0"
    readonly property color bgAlt:      "#E4DED0"
    readonly property color borderDim:  "#C5BFB5"
    readonly property color muted:      "#7A716A"
    readonly property color fg:         "#1F1812"
    readonly property color accentSoft: "#A8C0D5"
    readonly property color accentText: "#4A6F8E"
    readonly property color warn:       "#9C5450"

    // kitty bg, was @ 0.5 alpha — bumped to ~0.7 for more presence over dim wallpaper
    readonly property color boxFill:    "#B3F0EBE0"
    readonly property color boxBorder:  "#80C5BFB5"
    // dim layer over wallpaper — black @ ~0.50 (was 0.25, bumped +25pp)
    readonly property color dim:        "#80000000"

    readonly property string fontFamily: "Terminess Nerd Font Mono"
    readonly property int    fontSize:   16
}
