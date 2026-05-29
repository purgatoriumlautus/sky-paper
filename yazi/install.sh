#!/usr/bin/env bash
# Optional preview helpers for yazi on celestia.
#
# Why a script and not part of stow: these are pacman packages, not config.
# The yazi config itself is deployed with `stow yazi` (not this script).
#
# What it installs:
#   - ffmpegthumbnailer: video thumbnails in the preview pane
#   - poppler:           PDF page thumbnails (pdftoppm)
# Image previews work without these (kitty graphics, native formats).
#
# Revert: pacman -Rns ffmpegthumbnailer poppler   (if nothing else needs them)
set -euo pipefail

pacman -S --needed ffmpegthumbnailer poppler

echo "Installed. Spot-check:"
echo "  command -v ffmpegthumbnailer pdftoppm"
echo "Then open a video / PDF in yazi — the preview pane should show a thumbnail."
