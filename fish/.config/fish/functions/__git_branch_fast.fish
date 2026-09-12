# Ветка в промпте читается ИЗ ФАЙЛОВ, а не через `git`. Замерено: библиотечный
# fish_git_prompt стоил 22.5 ms на каждую отрисовку промпта в ~/dotfiles — это
# 98% стоимости всего fish_prompt (23.0 ms) и крупнейшая оставшаяся задержка
# после нажатия Enter. Отключение его опций давало только -22%: основная цена —
# сами обращения к git, а не опциональные проверки.
#
# Всё, что промпт показывал, лежит в служебных файлах репозитория, а fish умеет
# читать их встроенными командами (test / read / string / path — ни одного
# форка):
#   .git/HEAD                 "ref: refs/heads/<ветка>" либо голый SHA (detached)
#   .git/MERGE_HEAD           идёт мерж
#   .git/rebase-merge/        идёт ребейз (+ msgnum и end — прогресс)
#   .git/CHERRY_PICK_HEAD     идёт cherry-pick
#   .git/BISECT_LOG           идёт bisect
#
# Один случай сознательно НЕ реализован: когда .git не каталог, а файл
# ("gitdir: …" — worktree и submodule). Там разбор пришлось бы вести дальше по
# ссылке, и вместо этого мы отдаём работу настоящему fish_git_prompt: редкий
# случай остаётся правильным ценой тех же 22 ms.
#
# Тело файла исполняется при автозагрузке, до первого вызова функции, поэтому
# эти две настройки живут здесь, рядом с единственным, что их читает.
set -g __fish_git_prompt_showupstream none
set -g __fish_git_prompt_color_branch 8B7EC8

function __git_branch_fast --description 'Ветка и операция из файлов .git, без форков'
    # Подъём по родителям до каталога с .git
    set -l dir $PWD
    set -l gitdir ''
    while true
        if test -d $dir/.git
            set gitdir $dir/.git
            break
        else if test -e $dir/.git
            fish_git_prompt            # .git — файл: worktree/submodule, отдаём библиотеке
            return
        end
        test $dir = /; and break
        set dir (path dirname $dir)
    end
    test -z "$gitdir"; and return

    read -l head <$gitdir/HEAD; or return
    set -l name
    if set -l m (string match -r '^ref: refs/heads/(.+)$' -- $head)
        set name $m[2]
    else if test -n "$head"
        set name '('(string sub -l 8 -- $head)')'   # detached: fish рисует ((sha))
    else
        return
    end

    # Во время ребейза HEAD отсоединён, а имя перебазируемой ветки лежит
    # отдельно, в rebase-merge/head-name ("refs/heads/<ветка>") — иначе промпт
    # показывал бы SHA вместо ветки.
    set -l op ''
    if test -d $gitdir/rebase-merge
        read -l a <$gitdir/rebase-merge/msgnum
        read -l b <$gitdir/rebase-merge/end
        set -l i ''
        test -e $gitdir/rebase-merge/interactive; and set i '-i'
        set op "|REBASE$i $a/$b"
        if read -l hn <$gitdir/rebase-merge/head-name
            set -l hm (string match -r '^refs/heads/(.+)$' -- $hn)
            test -n "$hm[2]"; and set name $hm[2]
        end
    else if test -d $gitdir/rebase-apply
        set op '|REBASE'
        if read -l hn <$gitdir/rebase-apply/head-name
            set -l hm (string match -r '^refs/heads/(.+)$' -- $hn)
            test -n "$hm[2]"; and set name $hm[2]
        end
    else if test -e $gitdir/MERGE_HEAD
        set op '|MERGING'
    else if test -e $gitdir/CHERRY_PICK_HEAD
        set op '|CHERRY-PICKING'
    else if test -e $gitdir/BISECT_LOG
        set op '|BISECTING'
    end

    set_color $__fish_git_prompt_color_branch
    printf ' (%s%s)' $name $op
    set_color normal
end
