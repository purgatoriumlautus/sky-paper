import Quickshell

// Entry point. Flexoki Dark bar for niri — see Theme.qml / PALETTE.md.
// LockScreen is dormant until `qs ipc call lock lock` flips it on.
Scope {
    Bar {}
    LockScreen {}
}
