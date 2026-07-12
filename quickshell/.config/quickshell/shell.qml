import Quickshell
import Quickshell.Io

// Entry point. Flexoki Dark bar for niri — see Theme.qml / PALETTE.md.
//
// One Bar per monitor (Variants over Quickshell.screens), plus a SINGLE shared
// ControlCenter + Launcher that follow the focused output via `barScreen`
// (= the focused bar's screen). The CC/Launcher are LAYER SURFACES that take
// keyboard focus themselves — not grabbing PopupWindows. A grabbing popup needs
// its parent bar to have *received input*, which a compositor-eaten keybind
// never delivers, so it only opened on a click and the focus-then-open
// workaround added a visible lag. As layer surfaces they map + focus instantly
// from a keybind. (See ControlCenter.qml header.)
//
// NOTE: the popup ids are ccPopup/launcherPopup (not cc/launcher) so they don't
// shadow the Bar's `cc`/`launcher` properties in the Variants delegate below
// (that shadowing caused a self-referential binding loop).
//
// LockScreen is dormant until `qs ipc call lock lock` flips it on.
Scope {
    id: root

    // The bar on the focused niri output; the shared popups take its screen.
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

    // Shared popups — re-home to the focused bar's screen (see header).
    ControlCenter { id: ccPopup; barScreen: root.focusedBar ? root.focusedBar.screen : null }
    Launcher { id: launcherPopup; barScreen: root.focusedBar ? root.focusedBar.screen : null }

    LockScreen {}
}
