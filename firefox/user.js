// Force window.open(...) calls with feature parameters into a new tab instead
// of a popup window.
//
// Why: niri tiles popup-style firefox windows as half-screen siblings of the
// main browser because they share app_id="firefox" and firefox sets the title
// AFTER mapping the window — too late for niri's spawn-time `open-floating`
// title match. Forcing tabs sidesteps the whole class. OAuth flows continue
// to work as tabs.
//
// Reference values (firefox defaults are restriction=2, open_newwindow=3):
//   restriction=0 → apply open_newwindow even when window.open passes features
//   open_newwindow=3 → "new tab" (already default, listed for clarity)
user_pref("browser.link.open_newwindow.restriction", 0);
user_pref("browser.link.open_newwindow", 3);

// Route the file-chooser dialog through xdg-desktop-portal instead of
// firefox's own bundled GTK chooser.
//
// Why: the portal chooser (xdg-desktop-portal-gtk) is a standalone GTK3 process
// that reads ~/.config/gtk-3.0/gtk.css, so it inherits the Sky Paper / Win95
// theme and can be reloaded independently (restart the portal, not the whole
// browser). FF's bundled chooser only re-reads the theme on a full FF restart.
//   0 = never portal, 1 = always portal, 2 = auto (default; non-flatpak → never)
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
