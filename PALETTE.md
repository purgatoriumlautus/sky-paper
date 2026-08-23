# Palette — Flexoki Dark

Тёплый почти-чёрный «paper» фон, чернильный светлый текст, полная восьмёрка
Flexoki-акцентов (тона 400 — рассчитаны под тёмный фон). Главный UI-акцент —
purple. Источник: **flexoki.com** (Steph Ango), значения сверены с
`kepano/flexoki`. Контрасты посчитаны, не скопированы.

**Шрифты:** Terminess Nerd Font Mono (UI/kitty), Unifont (CJK/символы в
kitty через `symbol_map`), Terminus Italic (kitty курсив — кастомный,
собран в `terminus-italic/`).

---

## Base

| role | flexoki | hex | контраст к bg | назначение |
|---|---|---|---|---|
| **bg** | black | `#100F0F` | — | тёплый почти-чёрный, «бумага ночью» |
| bg-alt | base-950 | `#1C1B1A` | 1.1:1 | bars / panels / gutter / statusline |
| ui | base-850 | `#343331` | 1.5:1 | control faces, popovers, message bg |
| border-dim | base-800 | `#403E3C` | 1.8:1 | inactive borders, separators |
| faint | base-700 | `#575653` | 2.6:1 | ANSI bright-black, disabled, ghost text |
| muted | base-500 | `#878580` | 5.2:1 | комменты, inactive text (AA) |
| **fg** | base-200 | `#CECDC3` | **12:1** | основной текст |
| fg-max | paper | `#FFFCF0` | 18.6:1 | ANSI bright-white, редкие пики |
| **accent** | purple-400 | `#8B7EC8` | 5.4:1 | главный UI-акцент: рамки, selection, маркеры |
| accent-bright | purple-300 | `#A699D0` | 7.4:1 | hover/bright-вариант акцента |

Purple-400 тянет обе роли — и заливка, и текст (5.4:1), поэтому второй
акцент не нужен. **Правило:** на пурпурной заливке текст только тёмный
`#100F0F` (5.4:1); светлый fg на ней слепнет (2.2:1).

## Accents (все 400, контраст к bg)

| name | hex | к bg | роль в системе |
|---|---|---|---|
| red | `#D14D41` | 4.4:1 | error, urgent, destructive |
| orange | `#DA702C` | 5.8:1 | functions/builtins |
| yellow | `#D0A215` | 8.1:1 | types, warning |
| green | `#879A39` | 6.1:1 | keywords/control flow, ok/plus |
| cyan | `#3AA99F` | 6.7:1 | strings |
| blue | `#4385BE` | 4.9:1 | links, urls |
| purple | `#8B7EC8` | 5.4:1 | UI-акцент; numbers/constants в синтаксисе |
| magenta | `#CE5D97` | 5.1:1 | special/regex/escape |

Bright-ряд (ANSI 9–14) — те же hue, тон **300**: `#E8705F` `#A0AF54` `#DFB431`
`#66A0C8` `#E47DA8` `#5ABDAC` (все 6.3–9.8:1).

## Alpha-варианты (quickshell)

Composited поверх обоев, поэтому заданы как ARGB, а не как отдельные хексы:

| role | ARGB | = |
|---|---|---|
| barBg | `#BF1C1B1A` | bg-alt @ 0.75 |
| boxFill | `#D91C1B1A` | bg-alt @ 0.85 (lock + greeter) |
| boxBorder | `#80403E3C` | border-dim @ 0.5 |
| dim | `#80000000` | чёрный @ 0.5 (затемнение обоев под локом) |

---

## Syntax (nvim)

Структурная логика: control flow / verb / literal / weight-for-structure.

| role | hex | rationale |
|---|---|---|
| Normal fg | `#CECDC3` | tx |
| Comment | `#878580` italic | muted, AA |
| Keyword/Statement/Conditional | `#879A39` | green — control flow |
| Function/Builtin | `#DA702C` | orange — verb |
| Type/Class | `#D0A215` bold | yellow + weight = structural noun |
| String | `#3AA99F` | cyan — литерал |
| Number/Boolean | `#8B7EC8` | purple — literal data |
| Constant | `#8B7EC8` bold | purple + weight = structural |
| Operator | `#CECDC3` | fg (не muted — comment trap) |
| Property/Parameter | `#CECDC3` | = fg |
| Special/Regex/Escape | `#CE5D97` | magenta — «не обычный текст» |

## Diagnostics

| role | hex | note |
|---|---|---|
| error | `#D14D41` | bold + underline |
| warning | `#D0A215` | yellow |
| hint | `#878580` | muted |
| ok/plus | `#879A39` | green |
| delta | `#878580` | muted |

---

## Terminal 16-color (kitty)

Normal = 400, bright = 300.

| idx | ANSI | hex | note |
|---|---|---|---|
| 0 | black | `#100F0F` | bg |
| 1 | red | `#D14D41` | red-400 |
| 2 | green | `#879A39` | green-400 |
| 3 | yellow | `#D0A215` | yellow-400 |
| 4 | blue | `#4385BE` | blue-400 |
| 5 | magenta | `#CE5D97` | magenta-400 |
| 6 | cyan | `#3AA99F` | cyan-400 |
| 7 | white | `#CECDC3` | fg |
| 8 | br black | `#575653` | faint (base-700) |
| 9 | br red | `#E8705F` | red-300 |
| 10 | br green | `#A0AF54` | green-300 |
| 11 | br yellow | `#DFB431` | yellow-300 |
| 12 | br blue | `#66A0C8` | blue-300 |
| 13 | br magenta | `#E47DA8` | magenta-300 |
| 14 | br cyan | `#5ABDAC` | cyan-300 |
| 15 | br white | `#FFFCF0` | paper |

## Win95 bevel quad (gtk)

Рельеф: `hi > face > sh > dk` по светлоте. Белого highlight нет — на тёмной
панели он читается как неон.

| role | flexoki | hex |
|---|---|---|
| w95_face | base-850 | `#343331` |
| w95_hi | base-600 | `#6F6E69` |
| w95_sh | base-950 | `#1C1B1A` |
| w95_dk | black | `#100F0F` |

---

## Per-tool

**kitty:**
- bg `#100F0F`, fg `#CECDC3`
- cursor `#8B7EC8` (accent), block, с trail
- selection bg `#8B7EC8`, fg `#100F0F`
- url `#4385BE` (blue = links)
- active border `#8B7EC8`, inactive `#403E3C`, bell `#CECDC3`
- active tab bg `#8B7EC8` fg `#100F0F`; inactive bg `#1C1B1A` fg `#878580`
- font: Terminess Nerd Font Mono 12pt; курсив Terminus Italic (кастом);
  Unifont для CJK через `symbol_map U+3000-U+9FFF,U+F900-U+FAFF`

**niri** (square — no rounded corners):
- border 1px: active `#CECDC3` (fg ink, белая рамка — не accent fill),
  inactive `transparent`, urgent `#D14D41`
- focus-ring `off`
- shadow `on`, color `#00000066`, softness 15, spread 5, offset y6
  (тень на тёмном — чистый чёрный, не fg-based)
- tab-indicator: top, width 3, gap 6, radius 0, active `#8B7EC8`,
  inactive `#403E3C`, urgent `#D14D41`
- insert-hint `#8B7EC880`
- background-color `#100F0F` (fallback, если swaybg не поднялся)
- geometry-corner-radius 0 + clip-to-geometry
- overview backdrop `#1C1B1A`, workspace-shadow `#00000059` softness 30
  spread 4 offset y8
- layer-rule launcher: radius 0, shadow on
- обои: `mntvagaflexoki.png` (Vagabond-горы, инверс-гравюра: штрихи muted
  `#878580` на `#100F0F`; сорс в `wallpapers/`) через swaybg

**tmux:** hex в style-опциях тут не рендерится — только 256-палитра, так что
роли записаны ближайшими индексами (см. коммент в `tmux.conf`):

| роль | idx | ≈ |
|---|---|---|
| bar bg | `colour234` | bg-alt |
| bar fg / inactive window | `colour102` | muted |
| session marker + current window + активный pane-border + mode-style | `colour104` на `colour233` bold | accent на bg |
| pane border | `colour237` | border-dim |
| message | `colour251` на `colour236` | fg на ui |

**nvim:** vague colors override + кастомная тема lualine (роли выше).

**quickshell bar:**
- bar bg `barBg` (bg-alt @ 0.75) — прозрачная накладка, рассчитана на тёмные обои
- workspace fg `#878580`, active bg `#8B7EC8` fg `#100F0F`,
  urgent bg `#D14D41` fg `#100F0F`, empty `#403E3C`
- font: Terminess Nerd Font Mono 16px (`Theme.fontSize`), cellSize 32

**quickshell lock + greeter** (одна палитра на оба):
- бокс `boxFill` (bg-alt @ 0.85) поверх затемнённых обоев (`dim`),
  рамка `boxBorder`
- поля ввода без заливки: лейбл `#878580`, при фокусе → `#8B7EC8`;
  selection bg `#8B7EC8`, текст на ней `#100F0F`
- статус/ошибка `#D14D41`, крупные часы `#FFFCF0` (paper — редкий пик)
- font: Terminess Nerd Font Mono 16px, статусные строки на 2px меньше

**launcher (quickshell):**
- глиф `Δ` — accent `#8B7EC8`, в пару к `λ` на Control Center
- input текст `#CECDC3`, prompt `>`
- результаты — бокс вниз, цвет `barBg` (bg-alt @ 0.75), square
- selection bg `#8B7EC8`, текст `#100F0F`
- font Terminess Nerd Font Mono 16px (= bar)

**gtk (3 слоя):**
1. switches: `settings.ini` prefer-dark-theme=true; `apply.sh` color-scheme
   'prefer-dark' — иначе libadwaita/Firefox останутся светлыми изнутри
2. named colors: bg/view `#100F0F`, headerbar/sidebar/card `#1C1B1A`,
   popover `#343331`, fg `#CECDC3`, borders `#403E3C`, muted `#878580`,
   accent_bg `#8B7EC8` + accent_fg `#100F0F`, accent (standalone) `#8B7EC8`,
   link `#4385BE`, destructive/error `#D14D41`, warning `#D0A215`,
   success `#879A39`
3. Win95-хром: bevel quad выше; sunken-поля bg `#100F0F`, raised faces
   `#343331`; selection/hover bg `#8B7EC8` fg `#100F0F`; focus outline
   dotted `#CECDC3`

**zathura:** bg `#100F0F`, fg `#CECDC3`, statusbar/inputbar `#1C1B1A`,
highlight `#8B7EC8` (active `#A699D0`), recolor: lightcolor `#100F0F`
darkcolor `#CECDC3` (тёмный режим читалки = наш родной)

**mpv:** `mpv.conf` пишет цвета как `#AARRGGBB` (`FF` = непрозрачно):
background `#FF100F0F`, osd `#FFCECDC3`, osd-outline `#FF100F0F`.
`script-opts/osc.conf`: фон-элементы `#1C1B1A`, текст `#CECDC3`,
акцент `#8B7EC8`

**yazi:** директории и cwd — `#8B7EC8` (accent, не blue), selection и
маркеры bg `#8B7EC8` fg `#100F0F`, find-keyword accent bold italic
underline, hover-строки `#A699D0`

**fish:** git-branch в промпте `#8B7EC8` (и clean, и dirty); остальное —
дефолтные цвета fish поверх 16-цветной схемы kitty

**fastfetch:** accent `#8B7EC8` (ascii + ключи), muted `#878580`,
fg `#CECDC3` на `#100F0F`

**obsidian:** официальная тема Flexoki из каталога; свой только vimrc/hotkeys

**telegram (Desktop):** полный палитр-файл (467 vars). Пузыри монохромные —
входящие `#1C1B1A` (bg-alt), исходящие `#343331` (ui), текст всегда светлый;
purple — маркер, не заливка. Акцент `#8B7EC8`: кнопка отправки,
unread-бейдж, активный чат, reply-outline, selection, галочки; текст на
пурпуре только тёмный `#100F0F`. Ссылки blue `#66A0C8`, inline-code cyan,
8 цветов имён = кольцо акцентов 1:1. Фон чата — сплошной `#100F0F`
(вшитый тайл). Импорт через приложение, не stow — детали в `telegram/README`.
