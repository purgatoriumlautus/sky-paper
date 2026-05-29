import QtQuick
import Quickshell

// One row of three power-action cells. Modeled on the old CcFooterRow but
// with arm-then-confirm: a cell is "armed" when cc.armedRow/Col match —
// it pulses between Theme.accentText and Theme.bg until the 5 s armTimer
// expires, the user moves focus, or the user presses Enter a second time
// (which fires the action via cc.armOrFire).
//
// Flat command index (matches PowerActions.run): idx = rowIdx * 3 + col
// — computed at the MouseArea.onClicked site below and passed to
// cc.armOrFire so ControlCenter doesn't need to know our row position.
Item {
    id: row
    property var cc
    property int rowIndex: 10
    property int rowIdx: 0
    property var labels: ["A", "B", "C"]

    width: cc ? cc.width : 0
    height: 38

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === row.rowIndex) ? Theme.accentSoft : "transparent"
    }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: row.labels
            delegate: Rectangle {
                id: cell
                required property int index
                required property string modelData
                readonly property bool sel: cc && cc.focusedRow === row.rowIndex && cc.footerCol === index
                readonly property bool armed: cc && cc.armedRow === row.rowIndex && cc.armedCol === index
                width: (row.width - 24 - 8) / 3
                height: 28
                // base fill: armed phase set by SequentialAnimation when armed;
                // otherwise selected = accentText, idle = bg.
                color: armed ? armBg : (sel ? Theme.accentText : Theme.bg)
                border.color: Theme.borderDim

                // pulse state: when armed, animation alternates armPhase 0↔1
                // every 500 ms. armBg and labelColor read off armPhase so the
                // cell fill and its label flip together.
                property int armPhase: 0
                readonly property color armBg: armPhase === 0 ? Theme.accentText : Theme.bg
                readonly property color labelColor:
                    armed ? (armPhase === 0 ? Theme.barBg : Theme.fg)
                          : (sel ? Theme.barBg : Theme.fg)

                SequentialAnimation {
                    running: cell.armed
                    loops: Animation.Infinite
                    PropertyAction { target: cell; property: "armPhase"; value: 0 }
                    PauseAnimation { duration: 500 }
                    PropertyAction { target: cell; property: "armPhase"; value: 1 }
                    PauseAnimation { duration: 500 }
                }

                CcText {
                    anchors.centerIn: parent
                    text: modelData
                    color: cell.labelColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        row.cc.focusedRow = row.rowIndex;
                        row.cc.footerCol = cell.index;
                        row.cc.armOrFire(row.rowIndex, cell.index, row.rowIdx * 3 + cell.index);
                    }
                }
            }
        }
    }
}
