# fzf --fish и zoxide init выдают один и тот же текст, пока не обновится
# пакет, но стоили 13.7 + 6.5 ms из ~88 ms старта шелла — и платится это на
# КАЖДОЕ окно kitty, каждую панель tmux и каждый tmux-овский #(), потому что
# fish здесь ещё и default-shell. Кэшируем сгенерированный текст.
#
# Инвалидация по /var/lib/pacman/local, а НЕ по mtime самого бинаря: pacman
# сохраняет время СБОРКИ пакета, поэтому у свежеустановленного fzf mtime
# может оказаться старше кэша (проверено: /usr/bin/fzf → 2026-08-02, а
# установлен он позже) — и кэш никогда бы не обновился. Каталог базы pacman
# меняется при любой транзакции. `test` — встроенная команда, форка нет.
#
# Пишем через .new и проверяем непустоту: упавшая команда иначе оставила бы
# пустой кэш, и функция молча пропала бы до следующей установки пакета.
function __cached_init -a name cmd
    set -l c $__fish_cache_dir/$name.fish
    if not test -s $c; or test /var/lib/pacman/local -nt $c
        mkdir -p $__fish_cache_dir
        eval $cmd >$c.new 2>/dev/null
        test -s $c.new; and mv -f $c.new $c; or rm -f $c.new
    end
    test -s $c; and source $c
end
