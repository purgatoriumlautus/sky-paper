import QtQuick
import Quickshell

// CC Power-profile row (EPP cycler).
// Label left, current mode label right (in accent). H/L/Enter cycle in
// ControlCenter.qml; mouse click here cycles +1.
Item {
    id: row
    property var cc
    property int rowIndex: 0

    width: cc ? cc.width : 0
    height: 32

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === row.rowIndex) ? Theme.accentSoft : "transparent"
    }
    CcText {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "Power"
    }
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Power.labels[Power.mode]
        color: Theme.accentText
        elide: Text.ElideRight
        width: 180
        horizontalAlignment: Text.AlignRight
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { row.cc.focusedRow = row.rowIndex; Power.cycle(1); }
    }
}
