# Fish config — translated from celestia's .zshrc

# -----------------
# Greeting
# -----------------
set -U fish_greeting ""

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
# Misc
# -----------------
# AUTO_CD: fish doesn't have it natively. Emulate via command-not-found handler.
function fish_command_not_found
    if test -d $argv[1]
        cd $argv[1]
    else
        __fish_default_command_not_found_handler $argv
    end
end

# -----------------
# Editor + env
# -----------------
set -gx EDITOR nvim
set -gx LIBVIRT_DEFAULT_URI 'qemu:///system'
set -gx DISPLAY ':0'

# -----------------
# PATH
# -----------------
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/go/bin

# -----------------
# Aliases
# -----------------
alias ff='fastfetch'
alias vim='nvim'
alias ls='ls --color=auto'
alias ll='ls -la'
alias claer='clear'
alias se='sudoedit'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph'

# cloud storage
alias sync='rclone bisync ~/cloud storagebox:sync --check-access --fast-list'                                                                                                  

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
# Prompt — Flexoki Dark minimal
#   user@hostname /full/path (branch)
#   λ
# -----------------
set -g __fish_git_prompt_showupstream none
set -g __fish_git_prompt_color_branch 8B7EC8
set -g __fish_git_prompt_color_branch_dirty 8B7EC8

function fish_right_prompt
    set_color 878580
    date '+%H:%M'
    set_color normal
end

function fish_prompt
    set_color CECDC3
    echo -n $USER
    set_color 878580
    echo -n '@'
    set_color 8B7EC8
    echo -n $hostname
    set_color normal
    echo -n ' '
    set_color CECDC3
    echo -n (string replace -- $HOME '~' $PWD)
    printf '%s' (fish_git_prompt)
    set_color normal
    echo
    set_color 8B7EC8
    echo -n 'λ '
    set_color normal
end

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


# -----------------
# FZF (fuzzy finder)
# -----------------
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --exclude .git --exclude .cache'

function __fzf_edit_widget
    fd --hidden --type f --type d \
       --exclude proc --exclude sys --exclude dev --exclude run --exclude tmp --exclude mnt --exclude usr --exclude boot \
       --ignore-file ~/.config/fd/ignore \
       . / 2>/dev/null | fzf \
        --height 50% --layout=reverse \
        --preview '[ -d {} ] && eza --tree --level=2 --color=always {} || bat --color=always --style=numbers --line-range=:100 {}' \
        --preview-window=right:50%:wrap \
        --bind 'tab:down,btab:up' \
        --bind "enter:become($EDITOR {})"
    commandline -f repaint
end

fzf --fish | source 2>/dev/null

bind ctrl-t __fzf_edit_widget

bind ctrl-g fzf-cd-widget

bind ctrl-g fzf-cd-widget

# -----------------
# eza - smart ls
# -----------------

alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'

# -----------------
# zoxide — replaces cd, must be last
# -----------------
zoxide init fish --cmd cd | source
