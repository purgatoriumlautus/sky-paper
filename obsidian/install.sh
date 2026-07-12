#!/usr/bin/env bash
# obsidian on celestia — links the official Flexoki theme (vendored from
# github.com/kepano/flexoki-obsidian; Flexoki's author is Obsidian's CEO)
# + vimrc into the vault and patches appearance.json +
# community-plugins.json.
#
# This pkg is NOT stowed into ~/.config; Obsidian settings live per-vault
# under ~/Documents/Obsidian/second_brain/.obsidian/. The install.sh
# pattern mirrors firefox/ for the same reason (per-profile, not XDG).
#
# Vault path is hardcoded; override with VAULT=/path ./install.sh if you
# ever grow a second one.
#
# Revert:
#   rm "$VAULT/.obsidian/themes/Flexoki/theme.css"
#   rm "$VAULT/.obsidian/themes/Flexoki/manifest.json"
#   rm "$VAULT/.obsidian.vimrc"
#   then edit appearance.json + community-plugins.json by hand
set -euo pipefail

VAULT="${VAULT:-$HOME/Documents/Obsidian/second_brain}"
PKG="$(cd "$(dirname "$0")" && pwd)"
THEME_DIR="$VAULT/.obsidian/themes/Flexoki"
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

mkdir -p "$THEME_DIR"
ln -sfn "$PKG/flexoki/theme.css"     "$THEME_DIR/theme.css"
ln -sfn "$PKG/flexoki/manifest.json" "$THEME_DIR/manifest.json"
ln -sfn "$PKG/vimrc"                 "$VAULT/.obsidian.vimrc"
ln -sfn "$PKG/hotkeys.json"          "$VAULT/.obsidian/hotkeys.json"

# Retire the old Sky Paper snippet if a previous install linked it.
rm -f "$SNIP_DIR/sky-paper.css"

# appearance.json: force dark, select the Flexoki theme, switch accent,
# drop the old snippet.
# NB: "obsidian" is Obsidian's DARK base theme; "moonstone" is the LIGHT
# one. Flexoki paints both, but this system is Flexoki Dark (PALETTE.md).
# Accent = purple-400 #8B7EC8, the palette's main UI accent.
tmp=$(mktemp)
jq '
  .theme = "obsidian"
  | .cssTheme = "Flexoki"
  | .accentColor = "#8B7EC8"
  | .enabledCssSnippets = ((.enabledCssSnippets // []) - ["sky-paper"])
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
echo "  $THEME_DIR/{theme.css,manifest.json}  →  $PKG/flexoki/"
echo "  $VAULT/.obsidian.vimrc      →  $PKG/vimrc"
echo "  $VAULT/.obsidian/hotkeys.json →  $PKG/hotkeys.json"
echo
echo "Patched appearance.json: theme=obsidian (dark), cssTheme=Flexoki,"
echo "  accentColor=#8B7EC8, enabledCssSnippets -= sky-paper"
echo "Patched community-plugins.json: + obsidian-vimrc-support"
echo
echo "⚠  ONE MANUAL STEP — Obsidian's marketplace doesn't expose plugins"
echo "   to scripts. Open Obsidian → Settings → Community Plugins →"
echo "   Browse → install 'Vimrc Support'. The community-plugins.json"
echo "   entry we added will then activate it automatically on next launch."
echo
echo "ℹ  The cssTheme patch should select Flexoki automatically. If the"
echo "   theme doesn't take on next launch, pick it once by hand:"
echo "   Settings → Appearance → Themes → Flexoki."
