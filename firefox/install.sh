#!/usr/bin/env bash
# Install firefox user.js into the *.default-release profile.
#
# Why a script and not stow: the profile directory name is random
# ({hash}.default-release), so a fixed symlink path can't target it.
#
# What it does:
#   - Locates the *.default-release profile under ~/.mozilla/firefox (legacy)
#     or ~/.config/mozilla/firefox (XDG) — which one exists varies per install
#   - Among candidates, picks the one with the freshest prefs.js (the live profile)
#   - Copies user.js into it (overwrites existing user.js)
#   - Requires a firefox restart to take effect
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_ROOTS=("${HOME}/.mozilla/firefox" "${HOME}/.config/mozilla/firefox")

PROFILE=""
NEWEST=0
for root in "${PROFILE_ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r dir; do
        [[ -f "$dir/prefs.js" ]] || continue
        mtime=$(stat -c %Y "$dir/prefs.js")
        if (( mtime > NEWEST )); then
            NEWEST=$mtime
            PROFILE=$dir
        fi
    done < <(find "$root" -maxdepth 1 -type d -name "*.default-release")
done
[[ -n "$PROFILE" ]] || { echo "no *.default-release profile with prefs.js under ${PROFILE_ROOTS[0]} or ${PROFILE_ROOTS[1]}" >&2; exit 1; }

install -m 644 "$SRC/user.js" "$PROFILE/user.js"

echo "Installed user.js → $PROFILE/user.js"
echo "Restart firefox for changes to take effect."
