import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// iPhone-style shade, fully keyboard-driven (hjkl + Enter/Esc).
// Row grammar:
//   J/K  — move focus between rows / scroll an open list / wrap within power
//   H/L  — toggle flips / slider nudges ±5% / open list / commit list item
//   Enter — same as H/L per row (lists: commit; Volume: mute; power: arm/fire)
//   Esc/Q — disarm, then collapse open list, then hide power section, then close CC
// Rows (top → bottom):
//   0 Volume (slider)        3 Quiet (toggle — mako DND)
//   1 Warm (toggle)          4 Output (sink picker)
//   2 Auto-suspend (toggle)  5 Power profile (EPP cycler)
//
// (celestia desktop: Brightness/Airplane/BT/Wifi rows removed — no backlight,
//  no rfkill radios, no bluetooth, ethernet-only. Main section is 6 rows.)
//
// Power section (rows 10 & 11) is HIDDEN by default and only appears when
// togglePower is invoked (Mod+Shift+E IPC, see Bar.qml). When visible, J/K
// wraps within {10,11}. Esc hides it and returns focus to row 0.
//   10 Power session:  Lock · Logout · Sleep
//   11 Power system:   Hibernate · Reboot · Shutdown
// Both rows use arm-then-confirm: first Enter on a cell arms it (cell
// pulses, 5 s timer); second Enter on the SAME cell fires the PowerActions
// command and closes the CC. Moving focus disarms.
PopupWindow {
    id: cc

    property var anchorWin

    anchor.window: anchorWin
    anchor.rect.x: anchorWin ? anchorWin.width - cc.width - 9 : 0   // 9 = niri gaps+border
    anchor.rect.y: anchorWin ? anchorWin.height : 0
    implicitWidth: 300
    implicitHeight: shell.implicitHeight
    visible: false
    grabFocus: true
    color: "transparent"

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // --- nav state (backend state lives in the singletons: NightLight,
    //     SuspendInhibit, Notifications, AudioCtl, Power) ---

    property int focusedRow: 0
    property int footerCol: 0          // 0..2 within power footer rows (idx 10, 11)

    // Section-aware row nav: {0..5} (main rows) is one wrap group; {10,11}
    // (power rows) is another. J/K never crosses between groups. Entry to
    // the power group is via togglePower (Mod+Shift+E); exit is via Esc.
    property bool powerVisible: false

    // arm-then-confirm: when armedRow/Col point at a cell on rows 10 or 11,
    // that cell pulses for up to 5 s. Second Enter on the same cell fires;
    // moving focus, pressing Esc, or letting the timer expire disarms.
    property int armedRow: -1
    property int armedCol: -1

    // list-mode: -1 = nothing open. When set, Enter on a list row expands the
    // list and locks J/K/H/L to scrolling its items; Esc collapses.
    property int openRow: -1
    property int listSel: 0

    property bool closing: false

    function refresh() {
        NightLight.refresh();
        Power.refresh();
        Notifications.refresh();
    }
    onVisibleChanged: if (visible) {
        refresh();
        cc.focusedRow = 0;
        cc.footerCol = 0;
        cc.armedRow = -1;
        cc.armedCol = -1;
        cc.powerVisible = false;
        panel.forceActiveFocus();
    }

    // keep the highlighted sink index in range when sinks refresh under it
    Connections {
        target: AudioCtl
        function onSinksChanged() {
            // no control row here; sinks are 0..length-1
            if (cc.openRow === 4 && cc.listSel >= AudioCtl.sinks.length) cc.listSel = 0;
        }
    }

    Timer {
        id: armTimer
        interval: 5000
        onTriggered: cc.disarm()
    }

    function armCell(rowIndex, col) {
        cc.armedRow = rowIndex;
        cc.armedCol = col;
        armTimer.restart();
    }
    function disarm() {
        if (cc.armedRow === -1 && cc.armedCol === -1) return;
        cc.armedRow = -1;
        cc.armedCol = -1;
        armTimer.stop();
    }
    function armOrFire(rowIndex, col, flatIdx) {
        if (cc.armedRow === rowIndex && cc.armedCol === col) {
            PowerActions.run(flatIdx);
            cc.disarm();
            cc.closeCc();
        } else {
            cc.armCell(rowIndex, col);
        }
    }

    // J/K wraps within the focused row's section: {0..5} for the main rows,
    // {10,11} for the power rows. Crossing between sections is intentionally
    // impossible — entry to power is via togglePower, exit is via Esc.
    function advanceRow(dir) {
        if (cc.focusedRow >= 10) {
            cc.focusedRow = 10 + ((cc.focusedRow - 10 + dir + 2) % 2);
        } else {
            cc.focusedRow = (cc.focusedRow + dir + 6) % 6;
        }
    }

    // open/close stay mapped through the close animation
    function openCc() { closing = false; visible = true; openAnim.restart(); }
    function closeCc() { if (!visible || closing) return; closing = true; closeAnim.restart(); }
    property double lastToggle: 0
    function toggleCc() {
        var now = Date.now();
        if (now - lastToggle < 250) return;
        lastToggle = now;
        (visible && !closing) ? closeCc() : openCc();
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 210; easing.type: Easing.OutCubic }
        NumberAnimation { target: panelSlide; property: "y"; from: -10; to: 0; duration: 210; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 210; easing.type: Easing.InCubic }
        NumberAnimation { target: panelSlide; property: "y"; to: -10; duration: 210; easing.type: Easing.InCubic }
        onFinished: { cc.visible = false; cc.closing = false; cc.disarm(); cc.powerVisible = false; cc.closeList(); }
    }

    // --- volume ---
    function nudgeVolume(dir) {
        var s = Pipewire.defaultAudioSink;
        if (!s || !s.audio) return;
        s.audio.volume = Math.max(0, Math.min(1, s.audio.volume + dir * 0.05));
    }
    function toggleMute() {
        var s = Pipewire.defaultAudioSink;
        if (s && s.audio) s.audio.muted = !s.audio.muted;
    }

    // --- key dispatch ---
    function dispatchHL(dir) {
        switch (cc.focusedRow) {
            case 0: cc.nudgeVolume(dir); break;        // Volume
            case 1: NightLight.toggle(); break;        // Warm
            case 2: SuspendInhibit.toggle(); break;    // Auto-suspend
            case 3: Notifications.toggle(); break;     // Quiet (mako DND)
            case 4: cc.openList(); break;              // Output → expand sink picker
            case 5: Power.cycle(dir); break;           // Power profile (EPP)
            case 10:
            case 11: {
                cc.disarm();
                cc.footerCol = (cc.footerCol + dir + 3) % 3;
                break;
            }
        }
    }
    function handleEnter() {
        switch (cc.focusedRow) {
            case 0: cc.toggleMute(); break;            // Volume → mute
            case 1: NightLight.toggle(); break;
            case 2: SuspendInhibit.toggle(); break;    // Auto-suspend
            case 3: Notifications.toggle(); break;     // Quiet (mako DND)
            case 4: cc.openList(); break;              // Output → expand sink picker
            case 5: Power.cycle(1); break;             // Power profile (EPP)
            case 10:
            case 11: cc.armOrFire(cc.focusedRow, cc.footerCol, (cc.focusedRow - 10) * 3 + cc.footerCol); break;
        }
    }

    // --- list-mode (Output row 4 only — no toggle row, list is just sinks) ---
    function listLen() {
        if (cc.openRow === 4) return AudioCtl.sinks.length;
        return 0;
    }
    function openList() {
        cc.openRow = cc.focusedRow;
        cc.listSel = 0;
    }
    function closeList() {
        cc.openRow = -1;
    }
    function scrollList(dir) {
        var n = cc.listLen();
        if (n <= 0) return;
        cc.listSel = (cc.listSel + dir + n) % n;
    }
    function commitList() {
        if (cc.openRow === 4) {
            var sink = AudioCtl.sinks[cc.listSel];           // 0..N-1
            if (!sink) return;
            AudioCtl.setSink(sink);                          // make it the default
            cc.closeList();
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.barBg
        border.width: 0
        opacity: 0
        focus: true
        Keys.onPressed: (event) => {
            var k = event.key;
            var t = (event.text || "").toLowerCase();
            var listOpen = cc.openRow >= 0;
            // Russian (JCUKEN) duplicates: same physical positions (q/h/j/k/l)
            // drive nav with the Cyrillic layout active. Match event.text since
            // Qt's reported event.key for non-Latin keys is inconsistent.
            if (k === Qt.Key_Escape || k === Qt.Key_Q || t === "й") {
                if (cc.armedRow !== -1) cc.disarm();
                else if (listOpen) cc.closeList();
                else if (cc.powerVisible) {
                    cc.powerVisible = false;
                    cc.focusedRow = 0;
                    cc.footerCol = 0;
                }
                else cc.closeCc();
                event.accepted = true;
            } else if (k === Qt.Key_J || k === Qt.Key_Down || t === "о") {
                if (listOpen) cc.scrollList(+1);
                else { cc.disarm(); cc.advanceRow(+1); }
                event.accepted = true;
            } else if (k === Qt.Key_K || k === Qt.Key_Up || t === "л") {
                if (listOpen) cc.scrollList(-1);
                else { cc.disarm(); cc.advanceRow(-1); }
                event.accepted = true;
            } else if (k === Qt.Key_H || k === Qt.Key_Left || t === "р") {
                if (listOpen) cc.commitList(); else cc.dispatchHL(-1);
                event.accepted = true;
            } else if (k === Qt.Key_L || k === Qt.Key_Right || t === "д") {
                if (listOpen) cc.commitList(); else cc.dispatchHL(+1);
                event.accepted = true;
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                if (listOpen) cc.commitList(); else cc.handleEnter();
                event.accepted = true;
            }
        }
        transform: Translate { id: panelSlide; y: -10 }

        Column {
            id: shell
            width: cc.width
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: 0

            // 6px top breathing room so row 0's focus bg doesn't kiss the edge
            Item { width: cc.width; height: 6 }

            // 0 — Volume (keyboard Enter mutes; see handleEnter)
            CcSliderRow {
                cc: cc; rowIndex: 0; label: "Volume"
                property var s: Pipewire.defaultAudioSink
                suffix: (s && s.audio && s.audio.muted) ? " (muted)" : ""
                value: (s && s.audio) ? Math.round(s.audio.volume * 100) : 0
                onSeek: (f) => { if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1, f)); }
            }

            // 1 — Warm (wlsunset)
            CcToggleRow {
                cc: cc; rowIndex: 1; label: "Warm"
                on: NightLight.on
                onToggled: NightLight.toggle()
            }

            // 2 — Auto-suspend (off = block systemctl suspend)
            CcToggleRow {
                cc: cc; rowIndex: 2; label: "Auto-suspend"
                on: SuspendInhibit.enabled
                onToggled: SuspendInhibit.toggle()
            }

            // 3 — Quiet (mako DND)
            CcToggleRow {
                cc: cc; rowIndex: 3; label: "Quiet"
                on: Notifications.dnd
                onToggled: Notifications.toggle()
            }

            // 4 — Output (sink picker)
            OutputRow { cc: cc; rowIndex: 4 }

            // 5 — Power profile (EPP cycler — see Power.qml)
            PowerRow { cc: cc; rowIndex: 5 }

            // Power section (rows 10 + 11). Collapsed by default — animates in
            // when cc.powerVisible flips true (driven by togglePower / Esc).
            // clip:true so the rows don't render outside the animated bounds.
            Item {
                id: powerSection
                width: cc.width
                height: cc.powerVisible ? powerColumn.implicitHeight : 0
                opacity: cc.powerVisible ? 1 : 0
                clip: true
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Column {
                    id: powerColumn
                    width: parent.width
                    spacing: 0
                    // 10 — Power session: Lock · Logout · Sleep
                    PowerGridRow {
                        cc: cc; rowIndex: 10; rowIdx: 0
                        labels: ["Lock", "Logout", "Sleep"]
                    }
                    // 2 px safety-grade gap between session and system rows
                    Item { width: cc.width; height: 2 }
                    // 11 — Power system: Hibernate · Reboot · Shutdown
                    PowerGridRow {
                        cc: cc; rowIndex: 11; rowIdx: 1
                        labels: ["Hibernate", "Reboot", "Shutdown"]
                    }
                }
            }

            // 6px bottom breathing room
            Item { width: cc.width; height: 6 }
        }
    }
}
