# -----------------
# FZF (fuzzy finder)
# -----------------
# Сам виджет — в functions/__fzf_edit_widget.fish, кэширующая обёртка — в
# functions/__cached_init.fish (обе автозагружаемые).
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --exclude .git --exclude .cache'

__cached_init fzf 'fzf --fish'

# Биндить строго ПОСЛЕ __cached_init: `fzf --fish` вешает на Ctrl+T свой
# файловый виджет, и наш бинд его перекрывает. Поменять порядок — и вернётся
# fzf-овский.
bind ctrl-t __fzf_edit_widget

bind ctrl-g fzf-cd-widget
