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
set -gx DOCKER_BUILDKIT 1
set -gx COMPOSE_DOCKER_CLI_BUILD 1

# -----------------
# PATH
# -----------------
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/.local/bin/npm

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

# -----------------
# Vi mode
# -----------------
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_escape_delay_ms 10

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
# Visual-mode clipboard (Wayland via wl-copy/wl-paste)
# -----------------
# Fish ships fish_clipboard_copy / fish_clipboard_paste — wl-copy on Wayland.
bind --erase -M visual y 2>/dev/null
bind -M visual y fish_clipboard_copy end-selection repaint-mode
bind -M visual d 'fish_clipboard_copy; commandline -f kill-selection repaint-mode'
bind -M visual p 'commandline -f kill-selection; fish_clipboard_paste'

# Insert-mode useful keybinds (most are default in fish vi, kept for parity)
bind -M insert \cA beginning-of-line
bind -M insert \cE end-of-line
bind -M insert \cU kill-whole-line
bind -M insert \cK kill-line
bind -M insert \cW backward-kill-word
bind -M insert \cY yank
bind -M insert \cP up-or-search
bind -M insert \cN down-or-search

# -----------------
# FZF (fuzzy finder)
# -----------------
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git --exclude .cache . /home /etc /mnt'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND  'fd --type d --hidden --exclude .git --exclude .cache . /home /etc /mnt'
fzf --fish | source 2>/dev/null
bind -M insert \cG fzf-cd-widget

# Ctrl-D exits in default vi mode by preset, but is unbound in insert mode.
bind -M insert \cD delete-or-exit

# -----------------
# zoxide — replaces cd, must be last
# -----------------
zoxide init fish --cmd cd | source
