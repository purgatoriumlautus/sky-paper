#!/bin/sh
# Flexoki Dark GTK — dconf bits that can't live as a stowed file.
# libadwaita apps and the xdg-desktop-portal read these. Run once after `stow gtk`.
set -eu

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface font-name 'Terminess Nerd Font Mono 12'
gsettings set org.gnome.desktop.interface monospace-font-name 'Terminess Nerd Font Mono 12'

# retro icons — requires `gtk/icons-install.sh` to have been run first
gsettings set org.gnome.desktop.interface icon-theme 'Chicago95'

# Chicago95 white cursor — installed by gtk/icons-install.sh
gsettings set org.gnome.desktop.interface cursor-theme 'Chicago95_Standard_Cursors'
gsettings set org.gnome.desktop.interface cursor-size 24

echo "Flexoki Dark GTK applied. (Restart GTK apps to pick up changes.)"
