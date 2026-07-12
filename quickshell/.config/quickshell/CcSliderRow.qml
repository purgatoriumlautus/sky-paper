import QtQuick
import Quickshell

// Label + value% + 6px slider track. `value` is 0–100 (display + fill).
// Mouse press/drag emits seek(frac) with frac in 0..1; keyboard nudge is
// handled by ControlCenter's dispatchHL.
Item {
    id: row
    property var cc
    property int rowIndex: 0
    property string label: ""
    property string suffix: ""      // e.g. " (muted)"
    property int value: 0
    signal seek(real frac)

    // on the purple focus fill all text flips to Theme.bg (dark-on-accent rule)
    readonly property bool hl: cc && cc.focusedRow === row.rowIndex

    width: cc ? cc.width : 0
    height: 40

    Rectangle {
        anchors.fill: parent
        color: row.hl ? Theme.accentSoft : "transparent"
    }
    CcText {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.top: parent.top; anchors.topMargin: 6
        text: row.label + row.suffix
        color: row.hl ? Theme.bg : Theme.fg
    }
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.top: parent.top; anchors.topMargin: 6
        text: row.value + "%"
        color: row.hl ? Theme.bg : Theme.muted
    }
    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
        height: 6
        color: Theme.bg
        border.color: Theme.borderDim
        Rectangle {
            height: parent.height
            width: parent.width * row.value / 100
            color: Theme.accentText
        }
        MouseArea {
            anchors.fill: parent
            onPressed: { row.cc.focusedRow = row.rowIndex; row.seek(mouseX / width); }
            onPositionChanged: if (pressed) row.seek(mouseX / width)
        }
    }
}
