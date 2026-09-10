# Fish config — translated from celestia's .zshrc
#
# Сам конфиг разложен так, как это устроено у fish: этот файл — карта.
#
# conf.d/*.fish  подключается ЦЕЛИКОМ и по алфавиту, до этого файла:
#   00-env.fish      greeting, EDITOR и прочее окружение, PATH
#   10-keys.fish     набор биндов (emacs-пресет) и override'ы Ctrl+U / Ctrl+D
#   20-aliases.fish  алиасы: общие, git, rclone, eza
#   50-fzf.fish      FZF_ALT_C_COMMAND, кэш `fzf --fish`, бинды Ctrl+T / Ctrl+G
#   99-zoxide.fish   zoxide вместо cd — строго последним, отсюда и 99
#
# functions/*.fish  автозагрузка по имени, на старте шелла НЕ парсится:
#   fish_prompt              промпт (Flexoki Dark, две строки)
#   __git_branch_fast        ветка из файлов .git, без форков в git
#   fish_command_not_found   эмуляция AUTO_CD
#   __cached_init            кэш вывода `<tool> init`, инвалидация по pacman
#   __fzf_edit_widget        Ctrl+T: поиск файла по всей ФС → $EDITOR
#   yazi                     обёртка: cd в каталог, где вышли из yazi
#   __yazi_popup             тело tmux-попапа Alt+e
#
# Здесь имеет смысл держать только то, что должно выполниться ПОСЛЕ всего
# conf.d и не является ни функцией, ни автозагружаемым файлом. Сейчас такого
# нет — файл намеренно пуст.
