import QtQuick
import Quickshell

// BT row: collapsed shows the connected device; expanded is a scrollable
// picker (connection pip + pixel "unpaired" mark) with a power toggle at
// row 0. Nav state + connect logic live on `cc` (ControlCenter).
// Mirrors WifiRow; BT pairing has no typed secret, so no password field.
Item {
    id: root
    property var cc
    property int rowIndex: 6

    readonly property bool expanded: cc && cc.openRow === root.rowIndex
    readonly property var devs: BtCtl.devices || []
    // list row 0 = bluetooth power toggle; devices: idx 1..N
    readonly property var rows: [{ control: true }].concat(root.devs)
    readonly property int visRows: Math.min(rows.length, 6)

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
        id: btLabel
        anchors.left: parent.left; anchors.leftMargin: 12
        y: root.expanded ? 8 : Math.round((parent.height - height) / 2)
        text: "BT"
        color: root.hl ? Theme.bg : Theme.fg
    }
    CcText {
        id: btStatus
        anchors.right: parent.right; anchors.rightMargin: 12
        y: btLabel.y
        text: root.expanded
            ? (!BtCtl.powered ? "off"
               : (BtCtl.scanning ? "scanning…"
                  : (root.devs.length ? root.devs.length + " found" : "no devices")))
            : (Radio.airplaneOn ? "—"
               : (BtCtl.activeDevice ? BtCtl.activeDevice : (BtCtl.powered ? "on" : "off")))
        color: root.expanded ? Theme.muted
             : root.hl       ? Theme.bg
             : ((!Radio.airplaneOn && BtCtl.activeDevice) ? Theme.accentText : Theme.muted)
        elide: Text.ElideRight
        width: 150
        horizontalAlignment: Text.AlignRight
    }
    // header re-scan trigger — bitmap-native glyph, only while powered &
    // expanded. Not part of the j/k list nav, so ControlCenter also binds
    // `r` for keyboard parity. If ↻ renders mushy on Terminess, swap text
    // to "scan".
    CcText {
        id: rescanBtn
        visible: root.expanded && BtCtl.powered
        anchors.right: btStatus.left; anchors.rightMargin: 10
        y: btLabel.y
        // idle = static ↻; while a scan runs, cycle an ASCII spinner in the
        // accent colour so triggering it visibly does something. ASCII frames
        // stay crisp on the pixel font (rotating the glyph would blur it).
        property int spin: 0
        readonly property var frames: ["|", "/", "-", "\\"]
        text: BtCtl.scanning ? frames[spin] : "↻"
        color: BtCtl.scanning ? Theme.accentText : Theme.muted
        Timer {
            running: BtCtl.scanning
            repeat: true
            interval: 120
            onTriggered: rescanBtn.spin = (rescanBtn.spin + 1) % 4
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: BtCtl.scan()
        }
    }

    // scrollable device list
    ListView {
        id: btListView
        // stay mounted through the height animation so the clip reveals/hides
        // it smoothly instead of the items blinking in/out
        visible: root.height > 36
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 12; anchors.rightMargin: 12
        y: 30
        height: visible ? root.visRows * 26 : 0
        clip: true
        interactive: false
        model: root.rows
        currentIndex: root.cc ? root.cc.listSel : 0
        delegate: Item {
            id: devItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.cc.listSel
            width: ListView.view ? ListView.view.width : 0
            height: 26
            Rectangle {
                anchors.fill: parent
                color: devItem.sel ? Theme.accentText : "transparent"
            }
            // row 0: bluetooth power toggle — label + pixel switch
            CcText {
                visible: devItem.modelData.control === true
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: devItem.sel ? Theme.bg : Theme.fg
            }
            Item {
                visible: devItem.modelData.control === true
                width: 22; height: 12
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: BtCtl.powered
                        ? (devItem.sel ? Theme.bg : Theme.accentText)
                        : (devItem.sel ? Theme.bg : Theme.bgAlt)
                }
                Rectangle {
                    width: 8; height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: BtCtl.powered ? parent.width - width - 2 : 2
                    color: BtCtl.powered
                        ? (devItem.sel ? Theme.accentText : Theme.bg)
                        : Theme.muted
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            // connection pip: filled = connected, hollow = not
            Item {
                id: connPip
                visible: !devItem.modelData.control
                width: 7; height: 7
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: devItem.modelData.connected
                        ? (devItem.sel ? Theme.bg : Theme.accentText)
                        : "transparent"
                    border.width: devItem.modelData.connected ? 0 : 1
                    border.color: devItem.sel ? Theme.bg : Theme.borderDim
                }
            }
            CcText {
                visible: !devItem.modelData.control
                anchors.left: connPip.right; anchors.leftMargin: 8
                anchors.right: pairMark.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: devItem.modelData.name || ""
                color: devItem.sel ? Theme.bg
                     : (devItem.modelData.connected ? Theme.accentText
                        : ((devItem.modelData.paired && !devItem.modelData.inRange)
                           ? Theme.muted : Theme.fg))
            }
            // pixel "unpaired" mark — hollow square; only if not paired
            // (parallels WifiRow's padlock for secured networks)
            Item {
                id: pairMark
                width: 7; height: 7
                visible: !devItem.modelData.control && !devItem.modelData.paired
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: devItem.sel ? Theme.bg : Theme.muted
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.cc.listSel = devItem.index; root.cc.commitList(); }
            }
        }
    }

    MouseArea {
        visible: !root.expanded
        anchors.fill: parent
        onClicked: { root.cc.focusedRow = root.rowIndex; root.cc.openList(); }
    }
}
