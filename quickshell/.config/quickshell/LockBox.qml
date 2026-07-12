import QtQuick
import Quickshell

// Dark password box for the lock screen. Plain rectangle with one Field +
// hostname strip + status line. No internal animation — LockScreen drives
// the reveal by growing a parent slot's height (coordinated push with Clock).
Rectangle {
    id: box

    property string statusText: ""
    property color  statusColor: Theme.muted
    property alias  passwordText: passInput.text

    signal submitted()

    // Clear text only — focus is owned by LockScreen, which decides between
    // the field (revealed) and surfaceRoot (clock). Forcing focus here stole
    // it onto the hidden field on every lock/clear and broke reveal.
    function clear() { passInput.text = "" }

    function focusField() { passInput.forceActiveFocus() }

    // Wrong-password shake, fired by LockScreen on a failed attempt. Translate
    // (not anchors) so it doesn't fight the horizontalCenter anchor LockScreen
    // sets on us; ±14px stays inside boxSlot's 40px slack.
    function shake() { shakeAnim.restart() }

    width: 360
    height: 180
    radius: 0
    color: Theme.boxFill

    transform: Translate { id: shakeT }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeT; property: "x"; to:  14; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:   9; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:  -6; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to:   0; duration: 45 }
    }

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: parent.width - 56

        Text {
            width: parent.width
            text: "laniakea"
            color: Theme.muted
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }

        Field {
            id: passInput
            width: parent.width
            password: true
            textColor: Theme.fg
            onAccepted: box.submitted()
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: box.statusText
            color: box.statusColor
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
        }
    }
}
