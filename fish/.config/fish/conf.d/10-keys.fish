# -----------------
# Key bindings
# -----------------
# Default (emacs-style), NOT vi mode. Reason: fish's default preset is the
# same set macOS uses in every text field system-wide — Ctrl+A/E/K/Y,
# Option+Backspace, Option+arrows. One muscle memory for this shell, for the
# VSCode terminal on the work Mac, and for any Mac text field. A command line
# lives for seconds and needs no modes. See docs/keybinds.md.
set -g fish_key_bindings fish_default_key_bindings

# -----------------
# Keybind overrides
# -----------------
# Everything else comes from the default preset and must NOT be repeated here
# — Ctrl+A/E (line ends), Ctrl+K (kill to end), Ctrl+Y (yank), Ctrl+P/N
# (history), Ctrl+X / Ctrl+V (system clipboard via fish_clipboard_copy /
# _paste — wl-copy on Wayland), Alt+Backspace (kill word back), Alt+arrows
# (word motion), Right / Ctrl+F (accept autosuggestion).
#
# Ctrl+X is what copies a command line: it takes the *commandline buffer*,
# so nothing from the screen comes with it — no `λ ` prompt, no padding, no
# right-prompt clock. tmux copy-mode copies screen cells and cannot do that.
#
# The one real override: the preset's Ctrl+U is backward-kill-line (only up
# to the start). Whole line is what's actually wanted.
bind ctrl-u kill-whole-line

# The preset binds Ctrl+D to `exit`, which ends the shell process on an empty
# line — and a dead shell means tmux tears the pane down (or toggleterm's
# buffer dies). One stray keypress destroys a pane. Rebound to delete-char,
# which is also what Ctrl+D does in every macOS text field, so this stays in
# step with the rest of the preset. Panes close with Alt+q; shells with `exit`.
bind ctrl-d delete-char

# Биндов fzf здесь нет намеренно: наш Ctrl+T перебивает бинд из `fzf --fish`,
# то есть обязан выполниться ПОСЛЕ него — см. conf.d/50-fzf.fish.
