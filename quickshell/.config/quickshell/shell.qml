import Quickshell
import Quickshell.Io

// Entry point. Sky Paper bar for niri — see Theme.qml / PALETTE.md.
//
// One Bar per monitor (Variants over Quickshell.screens), but a SINGLE shared
// ControlCenter + Launcher live here and re-anchor to whichever bar owns the
// focused niri output (`focusedBar`). This is deliberate: instantiating the
// popups per-bar created several grabbing-popup objects across multiple layer
// surfaces, which Qt/niri can't parent correctly → the xdg_popup fails to map
// ("not an xdg_popup"). One popup object over one host surface = the working
// single-bar condition, while the popup still appears on the focused monitor.
//
// NOTE: the popup ids are ccPopup/launcherPopup (not cc/launcher) so they don't
// shadow the Bar's `cc`/`launcher` properties in the Variants delegate below
// (that shadowing caused a self-referential binding loop).
//
// LockScreen is dormant until `qs ipc call lock lock` flips it on.
Scope {
    id: root

    // The bar on the focused niri output; the shared popups anchor to it.
    property var focusedBar: null

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { ccPopup.toggleCc(); }
        function open(): void { ccPopup.openCc(); }
        function close(): void { ccPopup.closeCc(); }
        // togglePower: closed → open+show power+focus Lock; open&power → close;
        // open&no-power → reveal power. onVisibleChanged resets row/power on
        // open, so set them AFTER openCc().
        function togglePower(): void {
            if (ccPopup.visible && !ccPopup.closing && ccPopup.powerVisible) { ccPopup.closeCc(); return; }
            if (!ccPopup.visible || ccPopup.closing) ccPopup.openCc();
            ccPopup.powerVisible = true;
            ccPopup.focusedRow = 10;
            ccPopup.footerCol = 0;
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherPopup.toggle(); }
        function open(): void { launcherPopup.open(); }
        function close(): void { launcherPopup.close(); }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            host: root
            cc: ccPopup
            launcher: launcherPopup
        }
    }

    // Shared popups — re-anchor to the focused bar (see header).
    ControlCenter { id: ccPopup; anchorWin: root.focusedBar }
    Launcher { id: launcherPopup; anchorWin: root.focusedBar }

    LockScreen {}
}
