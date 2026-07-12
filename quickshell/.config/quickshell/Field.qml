import QtQuick

// Bare single-line input. No underline, no placeholder, no chrome.
// `input` exposed so LoginBox can wire KeyNavigation.tab between fields.
Item {
    id: field

    property alias text: input.text
    property alias input: input
    property bool password: false
    property color textColor: Theme.fg
    signal accepted()

    function clear() { input.text = "" }
    function forceActiveFocus() { input.forceActiveFocus() }

    implicitHeight: 24

    // Centered `> text` pair. Row is sized to its content so the whole
    // glyph sequence stays mirrored around the field's center.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            id: prompt
            anchors.verticalCenter: parent.verticalCenter
            text: ">"
            color: input.activeFocus ? Theme.accentText : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
        }

        TextInput {
            id: input
            width: 200
            anchors.verticalCenter: parent.verticalCenter
            color: field.textColor
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.bg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
            selectByMouse: true
            echoMode: field.password ? TextInput.Password : TextInput.Normal
            passwordCharacter: "*"
            onAccepted: field.accepted()
        }
    }
}
