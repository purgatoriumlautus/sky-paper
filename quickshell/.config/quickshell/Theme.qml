pragma Singleton

import QtQuick
import Quickshell

// Flexoki Dark — single source of truth for the whole shell.
// Edit here, everything re-themes. Mirrors ~/celestia/PALETTE.md.
// Purple pulls both accent roles (fill AND readable text, 5.4:1), so
// accentSoft/accentText collapse to the same value. Text ON the purple
// accent is always dark (Theme.bg) — light fg on it drops to 2.2:1.
Singleton {
    readonly property color bg:         "#100F0F"
    readonly property color bgAlt:      "#1C1B1A"
    readonly property color borderDim:  "#403E3C"
    readonly property color muted:      "#878580"
    readonly property color fg:         "#CECDC3"
    readonly property color fgMax:      "#FFFCF0"   // paper — rare peaks (big clocks)
    readonly property color accentSoft: "#8B7EC8"
    readonly property color accentText: "#8B7EC8"
    readonly property color warn:       "#D14D41"

    // bar background = bgAlt @ 0.75 (ARGB BF ≈ 0.749). Works over the dark
    // wallpaper; a light wallpaper would gray it out — bump toward E6 then.
    readonly property color barBg:      "#BF1C1B1A"

    // Lock-screen surfaces. boxFill = bgAlt @ ~0.85 over dim wallpaper.
    // dim = black @ ~0.50. Both mirror the greeter palette.
    readonly property color boxFill:    "#D91C1B1A"
    readonly property color boxBorder:  "#80403E3C"
    readonly property color dim:        "#80000000"

    // pixel size. waybar's Pango 12pt ≈ 16px @96dpi; Qt pt renders smaller,
    // so match by pixels. Nudge here if it still looks off.
    readonly property string fontFamily: "Terminess Nerd Font Mono"
    readonly property int    fontSize:   16
    readonly property int    barHeight:  22

    // every interactive cell (workspace digit, language, λ) is one fixed
    // box: height = barHeight, width = cellSize, glyph centered. Keeps all
    // cells identical & edges symmetric. Nudge cellSize to taste.
    readonly property int    cellSize:   32

    // launcher glyph — paired with the CC's λ. Core-Terminus letter (crisp).
    readonly property string launcherGlyph: "Δ";
}
