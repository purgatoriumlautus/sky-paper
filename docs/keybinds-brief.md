# Задача: спроектировать единую систему биндов заново

## Что нужно

Спроектировать **всю** систему клавиатурных биндов с нуля, целиком, учитывая
все слои одновременно. Не по одному конфигу — сразу всё вместе, как одну
систему.

Требования:

1. **Всё управляется с клавиатуры.** Мышь не нужна нигде.
2. **Vim-like логика** во всех слоях.
3. **Минимум нажатий.** Если действие можно повесить на одно сочетание — оно
   должно быть на одном. Лишние клавиши только там, где это неизбежно.
4. **Интуитивное расположение.** Бинды под пальцами, руки не уходят с
   домашнего ряда, логика запоминается сама.
5. **Работает на двух машинах одинаково.** Мышечная память не должна
   переключаться.
6. **Не привязываться к текущим биндам.** Можно взять их логику за основу,
   можно выкинуть полностью.

---

## Машины

### 1. Домашняя Linux-машина (Arch Linux, Wayland)

Две штуки, схема биндов у них общая: `laniakea` (ThinkPad X280) и
`celestia` (ПК). Отличия между ними — мониторы, батарея, wifi — на бинды не
влияют.

Стек: `niri` (компоновщик) → `kitty` → `tmux` → `fish` → `nvim`.
Плюс `keyd` (ремап на уровне ядра, есть root), `quickshell` (бар/лаунчер).
Клавиатуры: Epomaker X80 / Feker Galaxy80 (рапортуют Apple VID 05AC:024F, ими
рулит `hid_apple`), Keychron Q3 Max (QMK/VIA, программируется Keychron
Launcher по проводу), встроенная клавиатура ноутбука.
Раскладки: `us,ru`, переключение на `Alt+Shift` (`grp:alt_shift_toggle`).

### 2. Рабочий MacBook — managed

- Ставить софт **нельзя** (managed updates). Только то, что уже есть.
- Работа идёт в **VSCode**.
- Через плагин Remote-SSH подключение к **корпоративному Linux-серверу**.
- На сервере: `fish`, есть `sudo`, пакеты ставятся свободно. `tmux` пока не
  стоит, но поставить можно.
- Терминал — встроенный терминал VSCode (отдельный терминал, возможно,
  разрешат, но не факт).
- Оконным менеджментом на маке пользователь не занимается — только терминал,
  редактор и браузер.
- Клавиатура — встроенная в макбук (Keychron Q3 Max теоретически можно
  привезти, но схема не должна на это закладываться).

### Ключевое следствие

Дома есть root, keyd и любой софт. На маке нет ничего, кроме настроек
VSCode и встроенных настроек macOS. **Вся сложность должна падать на ту
машину, где есть права.**

---

## Полный инвентарь текущих биндов

### Слой 1 — `keyd` (ядро, /etc/keyd/default.conf)

```
capslock          -> f19        (leader для nvim)
Shift + capslock  -> capslock   (настоящий CapsLock)
```

Важное знание, добытое тяжёлым путём и записанное в комментарии конфига:
в дефолтном xkb-keymap `us` коды F13–F24 привязаны к вендорным keysym'ам,
которые терминалы молча выбрасывают (F13 → XF86Tools, F14–F18/F20–F24 →
XF86Launch*/XF86Touchpad*). **F19 — единственный код с чистым keysym'ом**,
доходящий по цепочке kitty → tmux → nvim.

### Слой 2 — `niri` (компоновщик), модификатор `Super` (= `Mod`)

```
Mod+Shift+Slash      show-hotkey-overlay
Mod+Return           spawn kitty
Mod+E                spawn kitty yazi
Mod+D                launcher (quickshell)
Super+Alt+L          lock
Super+Alt+S          orca
Mod+O                toggle-overview
Mod+Q                close-window
Mod+H / J / K / L    focus column/window влево/вниз/вверх/вправо
Mod+Shift+H/J/K/L    move column/window
Mod+Home / End       focus-column-first / last
Mod+Ctrl+Home/End    move-column-to-first / last
Mod+Ctrl+H / L       focus-monitor-left / right (только мультимонитор)
Mod+1..9             переключение воркспейса (на celestia — через скрипт sync-ws,
                     оба монитора разом; на laniakea обычный focus-workspace)
Mod+Shift+1..9       move-window-to-workspace
Mod+BracketLeft/Right   consume-or-expel-window
Mod+Comma / Period      consume / expel window into column
Mod+R / Mod+Shift+R     switch-preset-column-width (вперёд/назад)
Mod+Ctrl+R              reset-window-height
Mod+Ctrl+Shift+R        switch-preset-window-height
Mod+F                maximize-column
Mod+Shift+F          fullscreen-window
Mod+Ctrl+F           expand-column-to-available-width
Mod+M                maximize-window-to-edges
Mod+C                center-column
Mod+Ctrl+C           center-visible-columns
Mod+Minus / Equal    set-column-width -10% / +10%
Mod+Shift+Minus/Equal   set-window-height -10% / +10%
Mod+V                toggle-window-floating
Mod+Shift+V          switch-focus-between-floating-and-tiling
Mod+W                toggle-column-tabbed-display
Mod+Space            control center (quickshell)
Mod+Shift+E          power menu
Mod+Shift+P          power-off-monitors
Mod+Escape           toggle-keyboard-shortcuts-inhibit
Print / Ctrl+Print / Alt+Print   screenshot / screen / window
XF86Audio* / XF86MonBrightness*  мультимедиа
```

Итого ~60 биндов.

### Слой 3 — `kitty` (терминал), модификатор `kitty_mod = ctrl+shift`

```
kitty_mod+c    copy_to_clipboard          (+ дубль kitty_mod+с)
kitty_mod+v    paste_from_clipboard       (+ дубль kitty_mod+м)
kitty_mod+s    paste_from_selection       (+ дубль kitty_mod+ы)
kitty_mod+o    pass_selection_to_program  (+ дубль kitty_mod+щ)
shift+insert   paste_from_selection
kitty_mod+up / down / k / j    scroll_line_up / down  (+ дубли л / о)
kitty_mod+page_up / page_down  scroll_page
kitty_mod+home / end           scroll_home / end
kitty_mod+h    show_scrollback            (+ дубль kitty_mod+р)
```

Итого 14 биндов, из них 6 — кириллические дубли.

### Слой 4 — `tmux`, модификатор — **голый `Alt`** (префикса фактически нет)

```
# root-таблица полностью очищена: unbind-key -a -T root
M-z / M-я           copy-mode (в copy-mode тот же M-z = cancel, toggle)
M-h / M-j / M-k / M-l          select-pane влево/вниз/вверх/вправо
M-р / M-о / M-л / M-д          то же, кириллица
C-M-h/j/k/l (+ кириллица)      resize-pane
M-1 .. M-9          select-window 1..9
M-=                 split-window -h     (НЕ M-\: ESC+\ ломает OSC-ответы)
M--                 split-window -v
M-Enter             new-window
M-c / M-с           kill-pane
M-q / M-й           kill-window
M-Q / M-Й           confirm kill-session
M-d / M-в           detach          (+ prefix d / в)
M-r / M-к           reload config
M-s / M-ы           sesh popup (fzf-выбор сессии)
M-n / M-т           command-prompt: new-session
M-/ , M-?           поиск вперёд / назад в copy-mode
PageUp / PageDown   copy-mode -eu / send PageDown
WheelUp/Down        скролл / движение курсора в copy-mode

# copy-mode-vi
v                   begin-selection
V                   select-line
y                   copy-pipe-and-cancel "wl-copy || xclip -in -selection clipboard"
C-c                 cancel  (дефолт tmux — НЕ копирует)
+ 22 строки кириллических дублей на каждую vi-команду
  (р о л д ц и у Ц И У п П Р Ь Д т Т м М н Н й)

# prefix (дефолтный C-b) почти не используется
prefix z / я        copy-mode
prefix d / в        detach
```

Итого ~75 биндов, из них ~28 — кириллические дубли.

### Слой 5 — `fish` (шелл), режим `fish_vi_key_bindings`

```
# visual mode
y    fish_clipboard_copy end-selection repaint-mode
d    fish_clipboard_copy; kill-selection
p    kill-selection; fish_clipboard_paste

# insert mode (emacs-набор поверх vi)
Ctrl+A   beginning-of-line
Ctrl+E   end-of-line
Ctrl+U   kill-whole-line      (НЕ дефолтный backward-kill-line)
Ctrl+K   kill-line
Ctrl+W   backward-kill-word
Ctrl+Y   yank
Ctrl+P   up-or-search
Ctrl+N   down-or-search
Ctrl+G   fzf-cd-widget
Ctrl+D   delete-or-exit

# от fzf (плагин)
Ctrl+T   поиск файла
Ctrl+R   поиск по истории
Alt+C    cd (перекрыт на Ctrl+G)
```

### Слой 6 — `nvim`, leader = `F19` (от keyd)

```
Esc               nohlsearch
F19               -> <Leader>   (алиас)
x: p              "_dP  (paste без затирания регистра)
n: Ctrl+A         ggVG (select all)
+ / -             increment / decrement number
<leader>1..9      Ngt (вкладка N),  <leader>0 = tablast
<leader>wv / ws   split вертикальный / горизонтальный
<leader>wh/j/k/l  focus окна
<leader>wq        close окна
<leader>t         terminal toggle,  <leader>q  close panel
<F19>t / <F19>q   то же из terminal-режима
<leader>d         dashboard
<leader>gp/gr/gb  gitsigns: preview / reset / blame hunk
]c / [c           next / prev hunk
<leader>lr / la   LSP rename / code action
gd / gr / K       LSP definition / references / hover
]d / [d           diagnostic next / prev
s / S             flash jump / treesitter
Up/Down/Left/Right -> <Nop>   (стрелки отключены)
# nvim-tree: h/l закрыть/открыть, H/L root up/into, Ctrl+v/Ctrl+h открыть в сплите
```

Итого 50 биндов.

---

## Технические факты, выясненные в предыдущем обсуждении

Всё проверено, можно опираться.

### Модификаторы: что переживает цепочку клавиша → терминал → SSH → tmux

| Модификатор | Статус |
|---|---|
| `Ctrl`+буква | Работает везде одинаково (шлёт управляющий байт). Namespace тесный. |
| `Alt`/`Option` | На macOS Option — клавиша **композиции**, шлёт `ø`, `∆`, `˙` вместо Meta. Лечится настройкой терминала: в VSCode это `terminal.integrated.macOptionIsMeta`. |
| `Ctrl+Shift`+буква | В терминале **не отличается** от `Ctrl`+буква — легаси-кодировка схлопывает. Спасает только протокол клавиатуры kitty (CSI u); поддержка в терминале VSCode под вопросом. |
| `Super`/`Cmd` | До терминального приложения не доходит никогда. Только для WM. |

### Занятые `Ctrl`+буква (нельзя переиспользовать без потерь)

`Ctrl+A/E/K/U/W/Y/P/N/G/D` — fish (см. выше).
`Ctrl+T`, `Ctrl+R` — fzf.
`Ctrl+C`, `Ctrl+Z`, `Ctrl+D` — сигналы/EOF.
`Ctrl+L` — очистка экрана, жмётся постоянно.
`Ctrl+H` = `0x08` Backspace, `Ctrl+J` = `0x0A` перевод строки.
`Ctrl+S`/`Ctrl+Q` — XON/XOFF (нужен `stty -ixon`).

Свободные: примерно `Ctrl+X`, `Ctrl+O`, `Ctrl+F`, `Ctrl+B`.

### Ремап CapsLock

- Linux: `keyd`, любой таргет.
- macOS: System Settings → Keyboard → Modifier Keys. Встроенное, софт не
  нужен. Доступные цели: **Control, Option, Command, Escape, Globe/Fn**.
  В F19 или произвольную клавишу — **нельзя**.

### Прошивка Keychron Q3 Max (QMK/VIA)

Слой в прошивке шлёт наружу **обычные нажатия клавиш**, а не действия.
Едет вместе с клавиатурой, на маке ставить ничего не надо. Но не спасает от
проблемы Option на macOS: если прошивка шлёт Option+h, macOS всё равно
сделает из этого `˙`.

### Кириллица

- `Alt`+буква и голые буквы **зависят от раскладки** → нужны дубли.
- `Ctrl`+буква — как правило нет.
- F-клавиши — раскладочных вариантов не имеют вообще.
- В **nvim** проблема решается опцией `langmap` — одна строка вместо дублей.
- В **tmux** `langmap` нет, дубли неизбежны.

### Клипборд через SSH

На безголовом корпоративном сервере нет Wayland и X → `wl-copy` и `xclip`
(`tmux.conf:105`, `:133`) мертвы. Единственный механизм — **OSC 52**. Но
поддержка OSC 52 во встроенном терминале VSCode неполная: открытые issue
microsoft/vscode #104138, #122083, community discussion #153471 — именно про
Remote-SSH + tmux. **Требует эмпирической проверки.**

### Настройки VSCode, релевантные задаче

- `terminal.integrated.macOptionIsMeta` — без неё ни один Alt-бинд не дойдёт.
- `terminal.integrated.commandsToSkipShell` — что VSCode отдаёт шеллу вместо
  того, чтобы обработать самому.
- `terminal.integrated.allowChords` — иначе VSCode глотает начало аккордов.
- `terminal.integrated.enablePersistentSessions` — терминалы переживают
  разрыв SSH (то есть закрывает одну из функций tmux).
- `keybindings.json` поддерживает **аккорды нативно** (`"key": "ctrl+x 1"`) и
  условия `when` (например `terminalFocus`) — то есть tmux-подобную схему
  можно воспроизвести без расширений.
- Vim-логика в редакторе VSCode требует **расширения** — единственная
  позиция, требующая установки. Разрешат ли — неизвестно.

### Полезные готовые решения

- `vim-tmux-navigator` — одно сочетание переключает и сплиты vim, и панели
  tmux: tmux проверяет, запущен ли в панели vim, и либо прокидывает нажатие
  внутрь, либо переключает панель сам. Есть форк `vim-i3wm-tmux-navigator`,
  добавляющий слой WM. Модификатор настраивается, `Ctrl` не догма.
- Соглашение по namespace от LazyVim/which-key:
  `f`=find, `g`=git, `l`=lsp, `w`=window, `b`=buffer, `s`=search, `c`=code,
  `d`=debug/diagnostics, `u`=ui, `x`=diagnostics/quickfix, `q`=quit.

---

## Эргономика: физическая раскладка рук — ГЛАВНОЕ ТРЕБОВАНИЕ

Это не второстепенный критерий, а основной. Схема, не проработанная по
пальцам, не принимается.

### Исходная позиция

Домашний ряд: левая рука `a s d f`, правая `j k l ;`. Большие пальцы над
пробелом. Любое движение, уводящее руку с этой позиции, — это friction,
даже если формально «одно нажатие».

### Где физически лежат модификаторы (TKL, Keychron Q3 Max)

```
Ряд домашний:   [CapsLock] a s d f g   h j k l ; '
Нижний ряд:     [Shift]    z x c v b   n m , . /  [Shift]
Ряд модификат.: [Ctrl][Win/Opt][Alt/Cmd] ---- SPACE ---- [Alt][Fn][Ctrl]
```

- **CapsLock** — единственный модификатор **на домашнем ряду**. Левый мизинец
  достаёт её, не сдвигая кисть. Самая ценная клавиша на плате.
- **Левый Ctrl** — нижний левый угол. Мизинец обязан уйти с домашнего ряда
  вниз и скрючиться. Это классический источник «emacs pinky».
- **Левый Alt** — под левым большим пальцем. Большой палец сейчас нажимает
  **только пробел** и в остальном простаивает. Самый недоиспользованный
  палец на клавиатуре.
- **Правый Alt / правый Ctrl** — под правым большим/мизинцем, свободны.

### Конфликт, который надо решить явно

Если `CapsLock` отдать под один модификатор, второй остаётся в неудобном
углу. А `Ctrl` у пользователя **не редкий**: `Ctrl+A/E/K/U/W/Y/P/N/G/D` в
fish плюс `Ctrl+T`/`Ctrl+R` от fzf — это постоянная работа. То есть нельзя
просто сказать «Ctrl жмётся редко, потерпим».

Значит схема обязана ответить на вопрос: **чем именно нажимается каждый из
двух модификаторов, каким пальцем, и уходит ли при этом рука с домашнего
ряда.** Без этого ответа схема невалидна.

### Направления, которые стоит рассмотреть

- **Большие пальцы.** Оба сейчас заняты одним пробелом. Модификатор под
  большим пальцем не требует вообще никакого движения кисти. На маке
  ремапится встроенными средствами; на Linux — через keyd.
- **Разнести Ctrl и второй модификатор по разным рукам** (левый мизинец
  на CapsLock + правый большой на правый Alt), чтобы никогда не было
  одноручного зажима.
- **Home-row mods** — удержание `a/s/d/f` работает как модификатор.
  Ноль движения, но требует настройки тайминга tap/hold и даёт ложные
  срабатывания при быстрой печати. На маке без софта не воспроизводится
  (только через прошивку клавиатуры).
- **Слой в прошивке Q3 Max** — удержание одной клавиши переключает всю
  плату. Едет вместе с клавиатурой, на маке ничего ставить не надо. Но
  на встроенной клавиатуре макбука не работает.

### Правило для проверки любого бинда

1. Каким пальцем нажимается модификатор?
2. Уходит ли кисть с домашнего ряда?
3. Модификатор и клавиша — на разных руках? (одноручный зажим = плохо)
4. Насколько часто это действие? Частое обязано быть дешевле редкого.

---

## Что уже предлагалось и было отвергнуто

1. **Префиксная схема (`prefix` + клавиша, как в дефолтном tmux).**
   Отвергнуто: пользователь не хочет нажимать две комбинации подряд.
   Аккорды раздражают принципиально.

2. **`Ctrl+hjkl` для сквозной навигации.** Плохо: отбирает у шелла `Ctrl+L`
   (очистка экрана), `Ctrl+K` (kill-line пользователя), `Ctrl+H`, `Ctrl+J`.

3. **`CapsLock` → `Alt` + навигация на `Alt+hjkl`, окна на `Alt`+буква из
   словаря `<C-w>`/tmux, leader = `Space`.** Пользователя не устроило.

4. Существующая схема (голый `Alt` для всего в tmux) — работает дома,
   разваливается на маке и тащит 28 строк кириллических дублей.

---

## Что нужно на выходе

Полная, целостная схема биндов для **всех** слоёв сразу:

- `niri` (только дома)
- `kitty` (дома) и терминал VSCode (на работе)
- `tmux` (обе машины)
- `fish` (обе машины)
- `nvim` (дома) и редактор VSCode (на работе)
- `keyd` (дома) / встроенный ремап macOS (на работе)

С обоснованием: почему такой модификатор, почему такая буква, чем это
физически нажимается, и как ровно это же воспроизводится на маке.

Схема должна быть проверена на:
- конфликты между слоями и с дефолтами шелла/терминала;
- положение рук (модификатор и клавиша на разных руках, домашний ряд);
- частотность (частое = меньше нажатий);
- воспроизводимость на маке без установки софта, кроме расширения Vim.
