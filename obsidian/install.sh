#!/usr/bin/env bash
# obsidian on laniakea — links the Sky Paper snippet + vimrc into the
# vault and patches appearance.json + community-plugins.json.
#
# This pkg is NOT stowed into ~/.config; Obsidian settings live per-vault
# under ~/Documents/Obsidian/second_brain/.obsidian/. The install.sh
# pattern mirrors firefox/ for the same reason (per-profile, not XDG).
#
# Vault path is hardcoded; override with VAULT=/path ./install.sh if you
# ever grow a second one.
#
# Revert:
#   rm "$VAULT/.obsidian/snippets/sky-paper.css"
#   rm "$VAULT/.obsidian.vimrc"
#   then edit appearance.json + community-plugins.json by hand
set -euo pipefail

VAULT="${VAULT:-$HOME/Documents/Obsidian/second_brain}"
PKG="$(cd "$(dirname "$0")" && pwd)"
SNIP_DIR="$VAULT/.obsidian/snippets"
APP_JSON="$VAULT/.obsidian/appearance.json"
PLUGINS_JSON="$VAULT/.obsidian/community-plugins.json"

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; the script will sudo when it needs to." >&2
  exit 1
fi

[[ -d "$VAULT" ]] || { echo "Vault not found: $VAULT" >&2; exit 1; }

# Obsidian rewrites appearance.json / community-plugins.json on shutdown.
# If it's running, it will clobber our patches when it next closes.
if pgrep -x obsidian >/dev/null 2>&1; then
  echo "⚠  Obsidian is running. It will overwrite our JSON patches on close." >&2
  echo "   Close Obsidian first, then re-run." >&2
  exit 1
fi

sudo pacman -S --needed obsidian jq

mkdir -p "$SNIP_DIR"
ln -sfn "$PKG/sky-paper.css" "$SNIP_DIR/sky-paper.css"
ln -sfn "$PKG/vimrc"         "$VAULT/.obsidian.vimrc"
ln -sfn "$PKG/hotkeys.json"  "$VAULT/.obsidian/hotkeys.json"

# appearance.json: force light, switch accent, enable our snippet
tmp=$(mktemp)
jq '
  .theme = "obsidian"
  | .cssTheme = ""
  | .accentColor = "#4A6F8E"
  | .enabledCssSnippets = (((.enabledCssSnippets // []) + ["sky-paper"]) | unique)
' "$APP_JSON" > "$tmp" && mv "$tmp" "$APP_JSON"

# community-plugins.json: enable Vimrc Support (file is a JSON array of
# plugin IDs). The plugin files themselves still need a one-time install
# from the marketplace — see the printed instruction below.
if [[ -f "$PLUGINS_JSON" ]]; then
  tmp=$(mktemp)
  jq '(. + ["obsidian-vimrc-support"]) | unique' "$PLUGINS_JSON" > "$tmp" && mv "$tmp" "$PLUGINS_JSON"
else
  echo '["obsidian-vimrc-support"]' > "$PLUGINS_JSON"
fi

echo
echo "Linked:"
echo "  $SNIP_DIR/sky-paper.css     →  $PKG/sky-paper.css"
echo "  $VAULT/.obsidian.vimrc      →  $PKG/vimrc"
echo "  $VAULT/.obsidian/hotkeys.json →  $PKG/hotkeys.json"
echo
echo "Patched appearance.json: theme=obsidian (light), accentColor=#4A6F8E,"
echo "  enabledCssSnippets += sky-paper"
echo "Patched community-plugins.json: + obsidian-vimrc-support"
echo
echo "⚠  ONE MANUAL STEP — Obsidian's marketplace doesn't expose plugins"
echo "   to scripts. Open Obsidian → Settings → Community Plugins →"
echo "   Browse → install 'Vimrc Support'. The community-plugins.json"
echo "   entry we added will then activate it automatically on next launch."
