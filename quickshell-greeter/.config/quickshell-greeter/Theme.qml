pragma Singleton

import QtQuick
import Quickshell

// Flexoki Dark — greeter copy. Mirrors ~/dotfiles/quickshell/.config/quickshell/Theme.qml.
// Separate file because greeter runs as `greeter` user and can't traverse /home/aru (mode 700).
// If you re-tone the main palette, update this too. Text ON the purple accent
// is always dark (Theme.bg) — light fg on it drops to 2.2:1.
Singleton {
    readonly property color bg:         "#100F0F"
    readonly property color bgAlt:      "#1C1B1A"
    readonly property color borderDim:  "#403E3C"
    readonly property color muted:      "#878580"
    readonly property color fg:         "#CECDC3"
    readonly property color fgMax:      "#FFFCF0"   // paper — rare peaks (big clock)
    readonly property color accentSoft: "#8B7EC8"
    readonly property color accentText: "#8B7EC8"
    readonly property color warn:       "#D14D41"

    // form bg = bgAlt @ 0.85 (ARGB D9) over dim wallpaper — per PALETTE.md
    readonly property color boxFill:    "#D91C1B1A"
    readonly property color boxBorder:  "#80403E3C"
    // dim layer over wallpaper — black @ ~0.50 (was 0.25, bumped +25pp)
    readonly property color dim:        "#80000000"

    readonly property string fontFamily: "Terminess Nerd Font Mono"
    readonly property int    fontSize:   16
}
