import QtQuick
import Quickshell

// Label + pixel switch (22×12 track, 8×8 knob sliding L↔R).
// `cc` is the ControlCenter popup, injected for shared nav state.
Item {
    id: row
    property var cc
    property int rowIndex: 0
    property string label: ""
    property bool on: false
    signal toggled()

    width: cc ? cc.width : 0
    height: 32

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === row.rowIndex) ? Theme.accentSoft : "transparent"
    }
    CcText {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
    }
    Item {
        width: 22; height: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            // solid fills both states — borderDim is too close to the cream
            // bg and focus blue, so any outline disappears.
            color: row.on ? Theme.accentText : Theme.bgAlt
        }
        Rectangle {
            width: 8; height: 8
            anchors.verticalCenter: parent.verticalCenter
            x: row.on ? parent.width - width - 2 : 2
            color: row.on ? Theme.bg : Theme.muted
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { row.cc.focusedRow = row.rowIndex; row.toggled(); }
    }
}
