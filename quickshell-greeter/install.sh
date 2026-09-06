#!/usr/bin/env bash
# Install the Quickshell greetd greeter. Run with sudo.
#
# Why a script and not stow: the greeter runs as the `greeter` user, which
# cannot traverse $HOME (mode 700), so the QML + wallpaper must live under
# /etc, and /etc/greetd/config.toml + the /var/cache state dir are root-owned.
# None of that is stow-able — this script is the source of truth instead.
#
# Findings baked in (don't relearn the hard way):
#   - Qt under the minimal greetd/cage env defaults to the xcb plugin and dies
#     FATAL -> QT_QPA_PLATFORM=wayland in the greetd command.
#   - cage has no wlr-layer-shell -> Greeter.qml is a FloatingWindow, not a
#     PanelWindow. A layer surface never maps (blank screen + cursor).
#   - Do NOT wrap the launched session in `sh -c` (greetd execs it directly;
#     a wrapper exits immediately -> greeter bounce loop).
#   - greeter user has no readable runtime dir for qs logs; if debugging,
#     redirect qs stdout/stderr to /var/cache/quickshell-greeter/qs.log.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run with sudo" >&2; exit 1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QML_SRC="$SRC/.config/quickshell-greeter"
WALLPAPER_SRC="${WALLPAPER_SRC:-/home/aru/Pictures/wallpapers/mntvagaflexoki.png}"

# 1. QML -> /etc (world-readable; greeter user reads it here)
install -d -m 755 /etc/quickshell-greeter
install -m 644 "$QML_SRC"/*.qml /etc/quickshell-greeter/

# 2. Wallpaper -> /etc (Greeter.qml hardcodes this path)
install -m 644 "$WALLPAPER_SRC" /etc/quickshell-greeter/wallpaper.png

# 3. Remember-user state dir, writable by the greeter user
install -d -m 755 -o greeter -g greeter /var/cache/quickshell-greeter

# 4. greetd config (back up an existing one once)
[[ -f /etc/greetd/config.toml && ! -f /etc/greetd/config.toml.bak ]] \
    && cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
install -d -m 755 /etc/greetd
install -m 644 "$SRC/etc/greetd/config.toml" /etc/greetd/config.toml

echo "Installed. Apply with: systemctl restart greetd  (from a spare TTY)"
echo "Rollback greetd config: cp /etc/greetd/config.toml.bak /etc/greetd/config.toml"
