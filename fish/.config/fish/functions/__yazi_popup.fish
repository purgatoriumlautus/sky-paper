# Тело tmux-овского popup (Alt+e, см. tmux.conf). Живёт здесь, а не строкой
# внутри tmux.conf: popup исполняется через default-shell, а он берётся из
# окружения, в котором стартовал сервер, — fish-синтаксис в конфиге держался
# бы на этом совпадении. tmux зовёт `fish -c __yazi_popup`, и шелл задан явно
# (автозагрузка функций работает и в неинтерактивном fish).
#
# Вызывающую панель popup не получает параметром: `-e "VAR=#{pane_id}"` формат
# НЕ раскрывает (проверено на 3.7b — в переменную приходит literal `#{pane_id}`).
# Зато popup — не панель, активной для клиента остаётся та, из которой его
# позвали, поэтому `tmux display -p` изнутри и отвечает про неё.
#
# Прыжок делает обёртка yazi (functions/yazi.fish) — здесь остаётся передать
# результат наружу: popup умирает вместе со своим шеллом, поэтому конечный
# каталог впечатывается в вызывающую панель через send-keys. Ведущий пробел
# держит эту строку вне истории fish. Шлём только в шелл: под nvim (или любой
# другой программой в панели) буквы ушли бы в неё, поэтому команда панели
# проверяется.
function __yazi_popup
    set -l caller (tmux display -p '#{pane_id}')
    set -l caller_cmd (tmux display -p '#{pane_current_command}')
    set -l start $PWD
    yazi $argv
    test "$PWD" != "$start"
    and test "$caller_cmd" = fish
    and tmux send-keys -t $caller " cd -- " (string escape -- $PWD) Enter
end
