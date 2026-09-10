# -----------------
# zoxide — replaces cd, must be last
# -----------------
# «Last» — это имя файла: conf.d подключается в алфавитном порядке, так что
# 99- гарантирует, что переопределение `cd` идёт после всего остального.
__cached_init zoxide 'zoxide init fish --cmd cd'
