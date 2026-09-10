#!/usr/bin/env bash
# Deploy the fontconfig package. Run as your normal user (no sudo).
#
# Why a script and not plain stow: this package mixes two symlink targets
# that don't share a parent —
#   1. ~/.config/fontconfig/conf.d        (font matching rules)
#   2. ~/.local/share/applications/...     (Obsidian .desktop override)
# A single stow tree can't place both cleanly, so this script is the source
# of truth. It is idempotent: safe to re-run.
#
# What it links:
#   conf.d/                  -> global fontconfig rules (Terminess bitmap at
#                               native sizes, Unifont fallback, Terminus alias).
#   obsidian-fonts.conf      -> ~/.config/fontconfig/ (a SIBLING of conf.d, not
#                               inside it: fontconfig only auto-reads fonts.conf
#                               and conf.d/*, so this file stays inert globally
#                               and loads only via FONTCONFIG_FILE).
#   applications/obsidian.desktop -> overrides the pacman .desktop so Obsidian
#                               launches with FONTCONFIG_FILE=obsidian-fonts.conf
#                               (smooth Terminess at any size; bar stays crisp).
#
# The .desktop resolves that path through $HOME at runtime, so the same entry
# works on laniakea and celestia despite their different repo locations.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {  # link <target> <linkname>
    local target="$1" link="$2"
    install -d "$(dirname "$link")"
    # Refuse to clobber a real file/dir; only replace an existing symlink.
    if [[ -e "$link" && ! -L "$link" ]]; then
        echo "WARNING: $link exists and is not a symlink — leaving it. Remove it and re-run." >&2
        return
    fi
    ln -sfn "$target" "$link"
    echo "linked $link -> $target"
}

link "$SRC/conf.d"                     "$HOME/.config/fontconfig/conf.d"
link "$SRC/obsidian-fonts.conf"        "$HOME/.config/fontconfig/obsidian-fonts.conf"
link "$SRC/applications/obsidian.desktop" "$HOME/.local/share/applications/obsidian.desktop"

fc-cache -f "$HOME/.config/fontconfig" >/dev/null
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo
echo "Done. Restart Obsidian FROM A LAUNCHER (not 'obsidian' in a shell) so the"
echo ".desktop env var applies. Verify:"
echo "  FONTCONFIG_FILE=\$HOME/.config/fontconfig/obsidian-fonts.conf \\"
echo "    fc-match -v 'Terminess Nerd Font:pixelsize=16' | grep antialias  # -> True"
