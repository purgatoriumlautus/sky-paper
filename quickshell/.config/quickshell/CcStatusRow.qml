import QtQuick
import Quickshell

// Label + right-aligned status text. Used for read-only/placeholder rows
// (BT status, Power profile). Clicking just focuses the row.
Item {
    id: row
    property var cc
    property int rowIndex: 0
    property string label: ""
    property string status: ""
    property bool active: false

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
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.status
        color: row.active ? Theme.accentText : Theme.muted
        elide: Text.ElideRight
        width: 180
        horizontalAlignment: Text.AlignRight
    }
    MouseArea {
        anchors.fill: parent
        onClicked: row.cc.focusedRow = row.rowIndex
    }
}
