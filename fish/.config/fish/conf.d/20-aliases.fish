# -----------------
# Aliases
# -----------------
alias ff='fastfetch'
alias vim='nvim'
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
# eza - smart ls
# -----------------
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
