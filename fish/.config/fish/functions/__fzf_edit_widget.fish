# Ctrl+T (бинд — в conf.d/50-fzf.fish).
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
