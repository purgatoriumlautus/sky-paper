pragma Singleton

import Quickshell
import Quickshell.Io

// Footer power actions. Index matches the row-major grid in ControlCenter.qml:
//   row 10 (session): 0 Lock, 1 Logout, 2 Sleep
//   row 11 (system):  3 Hibernate, 4 Reboot, 5 Shutdown
// Mapping from (rowIndex, footerCol): idx = (rowIndex - 10) * 3 + footerCol.
Singleton {
    id: root
    function run(idx) {
        var cmds = [
            ["loginctl", "lock-session"],                                  // 0 Lock
            ["niri", "msg", "action", "quit", "--skip-confirmation"],      // 1 Logout
            ["systemctl", "suspend"],                                      // 2 Sleep
            ["systemctl", "hibernate"],                                    // 3 Hibernate
            ["systemctl", "reboot"],                                       // 4 Reboot
            ["systemctl", "poweroff"],                                     // 5 Shutdown
        ];
        proc.command = cmds[idx];
        proc.running = true;
    }
    Process { id: proc }
}
