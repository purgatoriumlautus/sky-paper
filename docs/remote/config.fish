# fish for the corporate Ubuntu box reached over Remote-SSH — copy to
#   ~/.config/fish/config.fish
#
# Derived from fish/.config/fish/config.fish on celestia. Same shell, same
# muscle memory; what is gone is only what has no meaning on a headless server
# (Wayland clipboard, libvirt, DISPLAY, rclone).
#
# ── Packages ────────────────────────────────────────────────────────────
#   REQUIRED   fish        — and it must be 4.x, see the key-binding note below
#   STRONGLY   tmux        — the session survives VSCode dying; see `tm` below
#              fzf         — Ctrl+T files, Ctrl+R history, Ctrl+G cd
#              fd-find     — installs the binary as `fdfind`, handled below
#              zoxide      — replaces cd
#   OPTIONAL   ripgrep bat neovim
#
#   sudo apt install tmux fzf fd-find ripgrep bat
#
#   zoxide is NOT in Ubuntu 22.04 (it entered the archive in 23.04). Check with
#   `apt-cache policy zoxide`; if empty, install it into ~/.local/bin instead:
#     curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
#
#   fish 4 is NOT in Ubuntu's archive (24.04 ships 3.7). Take it from upstream:
#     sudo add-apt-repository ppa:fish-shell/release-4 && sudo apt install fish
#
#   Why 4.x matters, concretely: `bind ctrl-u` is fish 4 syntax. On 3.x the
#   same line is silently a no-op and every override below quietly does
#   nothing. 3.x wants `bind \cu`. Rather than maintain two dialects, pin the
#   version — this file must stay diffable against celestia's.
#
#   No sudo on that box? Then fish alone is the blocker; everything else here
#   degrades on its own (see the `type -q` guards). Ask for fish, skip the rest.
#
#   DO NOT make fish the login shell here. VSCode Remote-SSH pipes a POSIX
#   bootstrap script into the login shell after authenticating; fish cannot
#   parse it, no markers come back, and the connection hangs until timeout
#   ("$PLATFORM is undefined in installation script output"). Login shell stays
#   bash; fish arrives through VSCode's terminal profile and through tmux's
#   default-shell instead — neither of which is a login shell.
#
#   tmux here is a session keeper, not a window manager — VSCode already owns
#   panes and windows on the Alt tier, and its keys never reach tmux anyway.
#   See docs/remote/tmux.conf. VSCode's own persistent sessions are not enough:
#   they do not survive VSCode being closed, which is how a running `apt
#   upgrade` got killed mid-transaction and took sshd with it.

# -----------------
# Greeting
# -----------------
set -U fish_greeting ""

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
# nvim if the box has it, vim otherwise. Editing happens in VSCode anyway;
# this is what git drops you into for a commit message.
if type -q nvim
    set -gx EDITOR nvim
else
    set -gx EDITOR vim
end

# NOT set here, unlike celestia: DISPLAY. The box is headless, and an exported
# DISPLAY only makes fish_clipboard_copy try xsel/xclip before giving up.

# -----------------
# PATH
# -----------------
fish_add_path -g $HOME/.local/bin
fish_add_path -g $HOME/go/bin

# -----------------
# Aliases
# -----------------
alias vim='nvim'
alias ls='ls --color=auto'
alias ll='ls -la'
alias claer='clear'
alias se='sudoedit'

# tmux, one session per project directory. `tmux new -A` attaches if the
# session exists and creates it otherwise, so `tm` is idempotent — run it in a
# fresh VSCode terminal and you land back exactly where you were, whether the
# last client left ten seconds or three days ago.
#
# Named after the directory rather than a fixed "main" so two projects do not
# end up mirroring each other's panes. Dots are illegal in tmux session names.
#
# NOT auto-run from this config: a shell that attaches to tmux on every start
# breaks `ssh host command`, scp and VSCode's own remote helpers, all of which
# spawn non-interactive shells. Explicit is the only safe form.
function tm --description 'Attach to (or create) a tmux session for this directory'
    set -l name (basename $PWD | string replace -a '.' '_')
    tmux new-session -A -s $name
end

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
# Key bindings
# -----------------
# Default (emacs-style), NOT vi mode — the same set macOS uses in every text
# field, so one muscle memory covers this shell, the VSCode terminal and any
# Mac text field. A command line lives for seconds and needs no modes.
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
# — Ctrl+A/E, Ctrl+K, Ctrl+Y, Ctrl+P/N, Ctrl+X / Ctrl+V (clipboard),
# Alt+Backspace, Alt+arrows, Right / Ctrl+F.
#
# Ctrl+X over SSH: it works, and needs nothing configured. fish_clipboard_copy
# tries pbcopy / wl-copy / xsel / xclip, finds none on a headless box, and then
# emits an OSC 52 escape carrying base64 — which the terminal at the far end
# (VSCode on the Mac) turns into a real clipboard write. It copies the
# COMMANDLINE BUFFER, so no prompt, padding or right-prompt clock comes along.
#
# If it turns out not to work, the cause is VSCode's OSC 52 support under
# Remote-SSH, not this config — microsoft/vscode#104138 and #122083. Probe:
#   printf '\033]52;c;%s\a' (printf hello | base64)
# then Cmd+V somewhere.

# The preset's Ctrl+U is backward-kill-line (only up to the start). Whole line
# is what's actually wanted.
bind ctrl-u kill-whole-line

# The preset binds Ctrl+D to `exit`, which ends the shell on an empty line.
# In a VSCode terminal that closes the terminal out from under you. Rebound to
# delete-char, which is what Ctrl+D does in every macOS text field.
bind ctrl-d delete-char

# Ctrl+W is left as the preset has it — backward-kill-path-component, one path
# segment per press, which beats killing a whole word in a shell.

# -----------------
# FZF (fuzzy finder)
# -----------------
# Ubuntu packages fd as `fdfind`; upstream and Arch call it `fd`. Take
# whichever exists, and fall back to `find` so the widgets still work on a box
# where neither is installed.
if type -q fd; or type -q fdfind
    set -l _fd (type -q fd; and echo fd; or echo fdfind)
    set -gx FZF_DEFAULT_COMMAND "$_fd --type f --hidden --exclude .git --exclude .cache ."
    set -gx FZF_ALT_C_COMMAND   "$_fd --type d --hidden --exclude .git --exclude .cache ."
else
    set -gx FZF_DEFAULT_COMMAND 'find . -type f -not -path "*/.git/*" -not -path "*/.cache/*"'
    set -gx FZF_ALT_C_COMMAND   'find . -type d -not -path "*/.git/*" -not -path "*/.cache/*"'
end
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND

# Search from the current directory, not from / — unlike celestia, where the
# roots are fixed (/home /etc /mnt). On a shared server the useful scope is
# wherever the project is.

# `fzf --fish` prints the shell integration, but only since fzf 0.53. Ubuntu's
# archive is older than that, and there the same bindings ship as a file.
if type -q fzf
    if fzf --fish >/dev/null 2>&1
        fzf --fish | source
    else if test -f /usr/share/doc/fzf/examples/key-bindings.fish
        source /usr/share/doc/fzf/examples/key-bindings.fish
        fzf_key_bindings
    end
    # Ctrl+T (files) and Ctrl+R (history) come from the integration itself.
    bind ctrl-g fzf-cd-widget 2>/dev/null
end

# -----------------
# zoxide — replaces cd, must be last
# -----------------
if type -q zoxide
    zoxide init fish --cmd cd | source
end
