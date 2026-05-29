#!/usr/bin/env bash
# zathura on laniakea — pacman pkgs + xdg-mime defaults.
#
# Why a script and not part of stow: these are system-level operations
# (pacman + xdg-mime), not config. The zathurarc itself is deployed with
# `stow zathura`.
#
# What it installs:
#   - zathura            : the viewer (GTK3)
#   - zathura-pdf-mupdf  : mupdf backend → PDF + ePub + XPS + CBZ + FB2
#
# poppler backend is not installed; mupdf renders nicer and covers more
# formats. If you ever switch, only one backend can be active at a time.
#
# xdg-mime defaults are set for the formats mupdf claims, so yazi's
# `o` (open with default) and firefox "open with system handler" route here.
#
# Revert: pacman -Rns zathura zathura-pdf-mupdf
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; the script will sudo when it needs to." >&2
  exit 1
fi

sudo pacman -S --needed zathura zathura-pdf-mupdf

# desktop file name shipped by the package
desktop="org.pwmt.zathura.desktop"

for mime in \
    application/pdf \
    application/epub+zip \
    application/oxps \
    application/vnd.ms-xpsdocument \
    application/vnd.comicbook+zip \
    application/x-cbz \
    application/x-cbr \
    ; do
  xdg-mime default "$desktop" "$mime"
done

echo
echo "Installed. Spot-check:"
echo "  xdg-mime query default application/pdf   # → $desktop"
echo "  zathura some.pdf                         # palette + Terminess statusbar"
