pragma Singleton

import QtQuick
import Quickshell

// Sky Paper — single source of truth for the whole shell.
// Edit here, everything re-themes. Mirrors ~/dotfiles/PALETTE.md.
Singleton {
    readonly property color bg:         "#F0EBE0"
    readonly property color bgAlt:      "#E4DED0"
    readonly property color borderDim:  "#C5BFB5"
    readonly property color muted:      "#7A716A"
    readonly property color fg:         "#1F1812"
    readonly property color accentSoft: "#A8C0D5"
    readonly property color accentText: "#4A6F8E"
    readonly property color warn:       "#9C5450"

    // bar background = bgAlt @ 0.75 (ARGB BF ≈ 0.749). Same as old waybar.
    readonly property color barBg:      "#BFE4DED0"

    // Lock-screen surfaces. boxFill = cream @ ~0.7 over dim wallpaper.
    // dim = black @ ~0.50. Both mirror the greeter palette.
    readonly property color boxFill:    "#B3F0EBE0"
    readonly property color boxBorder:  "#80C5BFB5"
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

    // right-cluster cells (wifi, battery, language, λ) hug their content with
    // this much horizontal padding each side. With Row spacing 0 every gap
    // between adjacent cells is therefore 2*cellPad — keeps them evenly spaced
    // regardless of differing glyph widths.
    readonly property int    cellPad:    7

    // launcher glyph — paired with the CC's λ. Core-Terminus letter (crisp).
    readonly property string launcherGlyph: "Δ";
}
