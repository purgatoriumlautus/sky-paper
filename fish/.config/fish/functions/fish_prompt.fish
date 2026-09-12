# -----------------
# Prompt — Flexoki Dark minimal
#   user@hostname /full/path (branch)
#   λ
# -----------------
# Ветка — из functions/__git_branch_fast.fish (чтение .git без форков).
#
# Правого промпта нет намеренно. В нём были часы, и `date` — внешний бинарь,
# то есть fork+exec на КАЖДУЮ отрисовку промпта, включая repaint после
# `commandline -f repaint` (в __fzf_edit_widget). Часы при этом уже есть в
# баре (quickshell/Clock.qml, «dd.MM HH:mm»), так что промпт их дублировал.
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
    __git_branch_fast
    set_color normal
    echo
    set_color 8B7EC8
    echo -n 'λ '
    set_color normal
end
