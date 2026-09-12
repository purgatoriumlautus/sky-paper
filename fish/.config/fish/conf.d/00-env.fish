# -----------------
# Greeting
# -----------------
# -g, не -U: приветствие — настройка сессии, а не персистентное состояние.
# `set -U` пишет в universal-хранилище (fish_variables, который лежит в
# этом же репозитории) на каждом старте шелла.
set -g fish_greeting ""

# -----------------
# History
# -----------------
# Fish defaults: shared, dedup, persistent. No setopt needed.
# HIST_IGNORE_SPACE → leading space already ignored by default in fish 3.6+.

# -----------------
# Completion
# -----------------
# Fish: built-in case-insensitive, colored, menu cycling. Nothing to configure.

# -----------------
# Editor + env
# -----------------
set -gx EDITOR nvim
set -gx LIBVIRT_DEFAULT_URI 'qemu:///system'
set -gx DOCKER_BUILDKIT 1
set -gx COMPOSE_DOCKER_CLI_BUILD 1

# -----------------
# PATH
# -----------------
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/.local/bin/npm
# Where `go install` drops binaries. Not where gopls comes from — that one is
# managed by mason under ~/.local/share/nvim. fish_add_path skips a directory
# that does not exist yet, so this stays inert until something lands there.
fish_add_path -g $HOME/go/bin
