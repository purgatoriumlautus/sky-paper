#!/usr/bin/env bash
# Install the custom Terminus Italic faces into the user font dir.
#
# Why a script and not stow: fonts live under ~/.local/share/fonts, not
# ~/.config (the stow target), and installing needs an fc-cache refresh.
#
# What it does:
#   - Copies fonts/*.ttf into ~/.local/share/fonts (overwrites existing)
#   - Refreshes the font cache so kitty picks up the "Terminus Italic" family
#
# kitty is already wired to these faces in kitty/.config/kitty/kitty.conf:
#   italic_font family="Terminus Italic"
#   bold_italic_font family="Terminus Italic" style="Bold Italic"
#
# To regenerate the TTFs (e.g. change the slant), see build.sh.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.local/share/fonts"

install -d -m 755 "$DEST"
install -m 644 "$SRC"/fonts/TerminusItalic-Regular.ttf "$DEST/"
install -m 644 "$SRC"/fonts/TerminusItalic-Bold.ttf    "$DEST/"

fc-cache -f "$DEST" >/dev/null

echo "Installed Terminus Italic (Italic + Bold Italic) to $DEST."
echo "Reload kitty (ctrl+shift+F5) to see it."
echo "Rollback: rm $DEST/TerminusItalic-*.ttf && fc-cache -f $DEST"
