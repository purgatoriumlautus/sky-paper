import QtQuick

// Shared Control-Center text style. Unifont is a pixel font; without
// NativeRendering + full hinting Qt blurs it.
Text {
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferFullHinting
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.fg
}
