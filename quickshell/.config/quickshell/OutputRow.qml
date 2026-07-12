import QtQuick
import Quickshell

// Output row: collapsed shows the active sink; expanded is a scrollable
// picker (filled pip = current default). Nav state + select logic live on
// `cc` (ControlCenter). Mirrors WifiRow/BtRow; audio has no daemon, so
// there is no power toggle at row 0 and no scan — the list is just sinks.
Item {
    id: root
    property var cc
    property int rowIndex: 8

    readonly property bool expanded: cc && cc.openRow === root.rowIndex
    readonly property var sinks: AudioCtl.sinks || []
    readonly property int visRows: Math.min(sinks.length, 6)

    // purple focus fill only while collapsed — expanded, the list's own
    // selection bar takes over (purple backdrop would swallow it), and all
    // text on the fill flips to Theme.bg (dark-on-accent rule).
    readonly property bool hl: cc && cc.focusedRow === root.rowIndex && !expanded

    width: cc ? cc.width : 0
    height: expanded ? 30 + visRows * 26 + 8 : 32
    // animate the expand/collapse so the list slides instead of popping;
    // clip masks the list as the row grows/shrinks around it.
    clip: true
    Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: root.hl ? Theme.accentSoft : "transparent"
    }

    CcText {
        id: outLabel
        anchors.left: parent.left; anchors.leftMargin: 12
        y: root.expanded ? 8 : Math.round((parent.height - height) / 2)
        text: "Output"
        color: root.hl ? Theme.bg : Theme.fg
    }
    CcText {
        anchors.right: parent.right; anchors.rightMargin: 12
        y: outLabel.y
        text: root.expanded
            ? (root.sinks.length ? root.sinks.length + " outputs" : "none")
            : AudioCtl.label(AudioCtl.currentSink)
        color: root.expanded ? Theme.muted
             : root.hl       ? Theme.bg
             : (AudioCtl.currentSink ? Theme.accentText : Theme.muted)
        elide: Text.ElideRight
        width: 150
        horizontalAlignment: Text.AlignRight
    }

    // scrollable sink list
    ListView {
        id: outListView
        // stay mounted through the height animation so the clip reveals/hides
        // it smoothly instead of the items blinking in/out
        visible: root.height > 36
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 12; anchors.rightMargin: 12
        y: 30
        height: visible ? root.visRows * 26 : 0
        clip: true
        interactive: false
        model: root.sinks
        currentIndex: root.cc ? root.cc.listSel : 0
        delegate: Item {
            id: sinkItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.cc.listSel
            readonly property bool isDefault: AudioCtl.currentSink === modelData
            width: ListView.view ? ListView.view.width : 0
            height: 26
            Rectangle {
                anchors.fill: parent
                color: sinkItem.sel ? Theme.accentText : "transparent"
            }
            // current-default pip: filled = active sink, hollow = not
            Item {
                id: defPip
                width: 7; height: 7
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: sinkItem.isDefault
                        ? (sinkItem.sel ? Theme.bg : Theme.accentText)
                        : "transparent"
                    border.width: sinkItem.isDefault ? 0 : 1
                    border.color: sinkItem.sel ? Theme.bg : Theme.borderDim
                }
            }
            CcText {
                anchors.left: defPip.right; anchors.leftMargin: 8
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: AudioCtl.label(sinkItem.modelData)
                color: sinkItem.sel ? Theme.bg
                     : (sinkItem.isDefault ? Theme.accentText : Theme.fg)
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.cc.listSel = sinkItem.index; root.cc.commitList(); }
            }
        }
    }

    MouseArea {
        visible: !root.expanded
        anchors.fill: parent
        onClicked: { root.cc.focusedRow = root.rowIndex; root.cc.openList(); }
    }
}
