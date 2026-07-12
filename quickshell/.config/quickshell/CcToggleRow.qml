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

    // on the purple focus fill all text flips to Theme.bg (dark-on-accent rule)
    readonly property bool hl: cc && cc.focusedRow === row.rowIndex

    width: cc ? cc.width : 0
    height: 32

    Rectangle {
        anchors.fill: parent
        color: row.hl ? Theme.accentSoft : "transparent"
    }
    CcText {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: row.hl ? Theme.bg : Theme.fg
    }
    Item {
        width: 22; height: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            // solid fills both states — any borderDim outline vanishes against
            // the dark panel and the purple focus fill. On the focus fill the
            // on-track goes dark (purple-on-purple would disappear).
            color: row.on ? (row.hl ? Theme.bg : Theme.accentText) : Theme.bgAlt
        }
        Rectangle {
            width: 8; height: 8
            anchors.verticalCenter: parent.verticalCenter
            x: row.on ? parent.width - width - 2 : 2
            color: row.on ? (row.hl ? Theme.accentSoft : Theme.bg) : Theme.muted
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { row.cc.focusedRow = row.rowIndex; row.toggled(); }
    }
}
