import QtQuick
import Quickshell

// Wifi row: collapsed shows active SSID; expanded is a scrollable picker
// (signal bars + pixel padlock) with an inline password field for secured,
// unknown networks. Nav state + connect logic live on `cc` (ControlCenter).
Item {
    id: root
    property var cc
    property int rowIndex: 7

    readonly property bool expanded: cc && cc.openRow === root.rowIndex
    readonly property var nets: WifiCtl.networks || []
    // list row 0 = wifi power toggle; scanned networks: idx 1..N
    readonly property var rows: [{ control: true }].concat(root.nets)
    readonly property int visRows: Math.min(rows.length, 6)

    width: cc ? cc.width : 0
    height: expanded
        ? 30 + (cc.askingPassword ? 34 : visRows * 26) + 8
        : 32
    // animate the expand/collapse so the list slides instead of popping;
    // clip masks the list as the row grows/shrinks around it.
    clip: true
    Behavior on height { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        color: (cc && cc.focusedRow === root.rowIndex) ? Theme.accentSoft : "transparent"
    }

    CcText {
        id: wifiLabel
        anchors.left: parent.left; anchors.leftMargin: 12
        y: root.expanded ? 8 : Math.round((parent.height - height) / 2)
        text: "Wifi"
    }
    CcText {
        id: wifiStatus
        anchors.right: parent.right; anchors.rightMargin: 12
        y: wifiLabel.y
        text: root.expanded
            ? (!WifiCtl.enabled ? "off"
               : (WifiCtl.scanning ? "scanning…"
                  : (root.nets.length ? root.nets.length + " found" : "no networks")))
            : (Radio.airplaneOn ? "—" : (WifiCtl.activeSsid || "off"))
        color: root.expanded ? Theme.muted
             : ((!Radio.airplaneOn && WifiCtl.activeSsid) ? Theme.accentText : Theme.muted)
        elide: Text.ElideRight
        width: 150
        horizontalAlignment: Text.AlignRight
    }
    // header re-scan trigger — mirrors BtRow. Idle = static ↻; while scanning,
    // cycle an ASCII spinner in the accent colour (ASCII stays crisp on the
    // pixel font — rotating the glyph would blur it).
    CcText {
        id: rescanBtn
        visible: root.expanded && WifiCtl.enabled
        anchors.right: wifiStatus.left; anchors.rightMargin: 10
        y: wifiLabel.y
        property int spin: 0
        readonly property var frames: ["|", "/", "-", "\\"]
        text: WifiCtl.scanning ? frames[spin] : "↻"
        color: WifiCtl.scanning ? Theme.accentText : Theme.muted
        Timer {
            running: WifiCtl.scanning
            repeat: true
            interval: 120
            onTriggered: rescanBtn.spin = (rescanBtn.spin + 1) % 4
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: WifiCtl.scan()
        }
    }

    // scrollable network list
    ListView {
        id: wifiListView
        // stay mounted through the height animation so the clip reveals/hides
        // it smoothly instead of the items blinking in/out
        visible: root.height > 36 && !root.cc.askingPassword
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 12; anchors.rightMargin: 12
        y: 30
        height: visible ? root.visRows * 26 : 0
        clip: true
        interactive: false
        model: root.rows
        currentIndex: root.cc ? root.cc.listSel : 0
        delegate: Item {
            id: netItem
            required property var modelData
            required property int index
            readonly property bool sel: index === root.cc.listSel
            width: ListView.view ? ListView.view.width : 0
            height: 26
            Rectangle {
                anchors.fill: parent
                color: netItem.sel ? Theme.accentText : "transparent"
            }
            // row 0: wifi power toggle — label + pixel switch (mirrors CcToggleRow)
            CcText {
                visible: netItem.modelData.control === true
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "Wi-Fi"
                color: netItem.sel ? Theme.bg : Theme.fg
            }
            Item {
                visible: netItem.modelData.control === true
                width: 22; height: 12
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: WifiCtl.enabled
                        ? (netItem.sel ? Theme.bg : Theme.accentText)
                        : (netItem.sel ? Theme.accentSoft : Theme.bgAlt)
                }
                Rectangle {
                    width: 8; height: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: WifiCtl.enabled ? parent.width - width - 2 : 2
                    color: WifiCtl.enabled
                        ? (netItem.sel ? Theme.accentText : Theme.bg)
                        : (netItem.sel ? Theme.bg : Theme.muted)
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            // signal bars (nmcli SIGNAL is 0–100)
            Row {
                id: sigBars
                visible: !netItem.modelData.control
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        readonly property int lit:
                            netItem.modelData.signal >= 75 ? 4 :
                            netItem.modelData.signal >= 50 ? 3 :
                            netItem.modelData.signal >= 25 ? 2 :
                            netItem.modelData.signal > 0   ? 1 : 0
                        width: 3
                        height: 3 + index * 3
                        anchors.bottom: parent.bottom
                        color: index < lit
                            ? (netItem.sel ? Theme.bg : Theme.fg)
                            : (netItem.sel ? Theme.accentSoft : Theme.borderDim)
                    }
                }
            }
            CcText {
                visible: !netItem.modelData.control
                anchors.left: sigBars.right; anchors.leftMargin: 8
                anchors.right: lockIcon.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: netItem.modelData.ssid || ""
                color: netItem.sel ? Theme.bg : (netItem.modelData.active ? Theme.accentText : Theme.fg)
            }
            // pixel padlock — shackle (3-tall outline) + body; only if secured
            Item {
                id: lockIcon
                width: 7; height: 8
                visible: !netItem.modelData.control && netItem.modelData.secured
                anchors.right: parent.right; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 5; height: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    color: "transparent"
                    border.width: 1
                    border.color: netItem.sel ? Theme.bg : Theme.muted
                }
                Rectangle {
                    width: 7; height: 5
                    anchors.bottom: parent.bottom
                    color: netItem.sel ? Theme.bg : Theme.muted
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.cc.listSel = netItem.index; root.cc.commitList(); }
            }
        }
    }

    // password entry (shown after picking a secured, unknown network)
    Rectangle {
        visible: root.expanded && root.cc.askingPassword
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 12; anchors.rightMargin: 12
        y: 30
        height: visible ? 28 : 0
        color: Theme.bg
        border.color: Theme.accentText
        CcText {
            anchors.left: parent.left; anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: pwInput.text.length === 0
            text: "password for " + root.cc.pendingSsid
            color: Theme.muted
            elide: Text.ElideRight
            width: parent.width - 12
        }
        TextInput {
            id: pwInput
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 6; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            echoMode: TextInput.Password
            color: Theme.fg
            renderType: Text.NativeRendering
            font.hintingPreference: Font.PreferFullHinting
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
            onAccepted: root.cc.connectWifi(root.cc.pendingSsid, text)
            Keys.onEscapePressed: root.cc.closeList()
        }
    }

    MouseArea {
        visible: !root.expanded
        anchors.fill: parent
        onClicked: { root.cc.focusedRow = root.rowIndex; root.cc.openList(); }
    }
}
