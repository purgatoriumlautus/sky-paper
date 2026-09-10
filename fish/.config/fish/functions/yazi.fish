# -----------------
# yazi — cd on exit
# -----------------
# Обёртка поверх самого `yazi` (внутри — `command yazi`, рекурсии нет), а не
# отдельная `y`: прыжок нужен на каждом выходе, а не только когда вспомнил
# набрать другое имя. yazi пишет свой последний cwd в файл, шелл читает и
# переходит туда. `Q` выходит без прыжка — тогда yazi файл не пишет вовсе.
#
# Прыгаем через `cd`, то есть через zoxide (conf.d/99-zoxide.fish переопределяет
# cd), так что каталог попадает в базу частых. GUI-запуск мимо шелла (yazi-kitty
# .desktop) вызывает бинарь напрямую и этой обёртки не видит.
function yazi --wraps yazi
    set -l cwd_file (mktemp -t yazi-cwd.XXXXXX)
    command yazi --cwd-file=$cwd_file $argv
    set -l dir (cat -- $cwd_file 2>/dev/null)
    rm -f -- $cwd_file
    if test -n "$dir"; and test "$dir" != "$PWD"
        cd -- $dir
    end
end
