#!/bin/sh
# Install the Chicago95 retro icon theme + white cursor theme (the Win95 look
# that pairs with the Sky Paper / Win95-bevel GTK css). Not vendored: Chicago95
# is 30MB / 4000 files, so we fetch upstream — same rationale as firefox/install.sh.
#
# What it does:
#   - clones Chicago95 (shallow) to a temp dir
#   - icons → ~/.local/share/icons/Chicago95, patched with `Inherits=Adwaita,hicolor`
#     so missing symbolic icons (GTK4 needs many Chicago95 lacks) fall back
#     instead of rendering blank; rebuilds the icon cache
#   - cursors → ~/.icons/Chicago95_Standard_Cursors (classic white Win95 pointer)
# Select both with `gtk/apply.sh` (icon-theme + cursor-theme gsettings).
set -eu

ICONS="${HOME}/.local/share/icons/Chicago95"
CURSORS="${HOME}/.icons/Chicago95_Standard_Cursors"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/grassmunk/Chicago95 "$TMP/Chicago95"

mkdir -p "${HOME}/.local/share/icons" "${HOME}/.icons"
rm -rf "$ICONS" "$CURSORS"
cp -r "$TMP/Chicago95/Icons/Chicago95" "$ICONS"
cp -r "$TMP/Chicago95/Cursors/Chicago95_Standard_Cursors" "$CURSORS"

# fall back to Adwaita for any icon (esp. symbolics) Chicago95 lacks
grep -q '^Inherits=' "$ICONS/index.theme" \
  || sed -i '/^Example=folder/a Inherits=Adwaita,hicolor' "$ICONS/index.theme"

gtk-update-icon-cache -q -f "$ICONS" 2>/dev/null || true

echo "Chicago95 icons → $ICONS"
echo "Chicago95 white cursors → $CURSORS"
echo "Run gtk/apply.sh to select them."
