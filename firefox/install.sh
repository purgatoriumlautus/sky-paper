#!/usr/bin/env bash
# Install firefox user.js into the *.default-release profile.
#
# Why a script and not stow: the profile directory name is random
# ({hash}.default-release), so a fixed symlink path can't target it.
#
# What it does:
#   - Locates the *.default-release profile under ~/.config/mozilla/firefox
#   - Copies user.js into it (overwrites existing user.js)
#   - Requires a firefox restart to take effect
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${HOME}/.config/mozilla/firefox"

PROFILE=$(find "$PROFILES_DIR" -maxdepth 1 -type d -name "*.default-release" | head -n1)
[[ -n "$PROFILE" ]] || { echo "no *.default-release profile under $PROFILES_DIR" >&2; exit 1; }

install -m 644 "$SRC/user.js" "$PROFILE/user.js"

echo "Installed user.js → $PROFILE/user.js"
echo "Restart firefox for changes to take effect."
