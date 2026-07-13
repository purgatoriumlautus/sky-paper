# Palette — Flexoki Dark (warm ink & paper, ночная версия)

Тёплый почти-чёрный «paper» фон, чернильный светлый текст, полная восьмёрка
Flexoki-акцентов (тона 400 — рассчитаны под тёмный фон). Главный UI-акцент —
purple. Источник: **flexoki.com** (Steph Ango), значения сверены с
`kepano/flexoki` 2026-07-11. Контрасты ниже посчитаны, не скопированы.

**Источник:** flexoki.com, adopted as-is 2026-07-11. Четвёртая итерация
(dark Cool Mono → light Cool Paper → light Sky Paper → **Flexoki Dark**).
Дизайн-решения перехода: `docs/superpowers/specs/2026-07-11-flexoki-dark-transition-design.md`.

**Шрифты:** Terminess Nerd Font Mono (UI/kitty), Unifont (CJK/символы),
Terminus Italic (kitty курсив — кастомный, собран в `terminus-italic/`).

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

Ключевое упрощение vs Sky Paper: там нужны были **два** акцента (sky 1.7:1 не
читался как текст). Purple-400 на тёмном фоне тянет обе роли — и заливка, и
текст (5.4:1). Но на самой пурпурной заливке текст **только тёмный** `#100F0F`
(5.4:1); светлый fg на ней слепнет (2.2:1) — то же правило, что было со sky.

## Accents (все 400, контраст к bg)

| name | hex | к bg | роль в системе |
|---|---|---|---|
| red | `#D14D41` | 4.4:1 | error, urgent, destructive |
| orange | `#DA702C` | 5.8:1 | functions/builtins |
| yellow | `#D0A215` | 8.1:1 | types, warning |
| green | `#879A39` | 6.1:1 | keywords/control flow, ok/plus |
| cyan | `#3AA99F` | 6.7:1 | strings |
| blue | `#4385BE` | 4.9:1 | links, urls, directories |
| purple | `#8B7EC8` | 5.4:1 | UI-акцент; numbers/constants в синтаксисе |
| magenta | `#CE5D97` | 5.1:1 | special/regex/escape |

Bright-ряд (ANSI 9–14) — те же hue, тон **300**: `#E8705F` `#A0AF54` `#DFB431`
`#66A0C8` `#E47DA8` `#5ABDAC` (все 6.3–9.8:1).

---

## Syntax (nvim)

Структурная логика nvim-syntax-v2 сохранена (control flow / verb / literal /
weight-for-structure), цвета — Flexoki:

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
| error | `#D14D41` | bold + underline — теперь настоящий red |
| warning | `#D0A215` | yellow |
| hint | `#878580` | muted |
| ok/plus | `#879A39` | green |
| delta | `#878580` | muted |

---

## Terminal 16-color (kitty)

Полноцветная схема (Sky Paper схлопывал каналы — Flexoki нет). Normal = 400,
bright = 300.

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

---

## Win95 bevel quad (gtk)

Рельеф сохранён: `hi > face > sh > dk` по светлоте. Белый highlight мёртв —
на тёмной панели он неон.

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
- cursor `#8B7EC8` (accent)
- selection bg `#8B7EC8`, fg `#100F0F` (только тёмный текст на акценте)
- url `#4385BE` (blue = links)
- active border `#8B7EC8`, inactive `#403E3C`, bell `#CECDC3`
- active tab bg `#8B7EC8` fg `#100F0F`
- inactive tab bg `#1C1B1A` fg `#878580`
- font: Terminess Nerd Font Mono 12pt; курсив Terminus Italic (кастом);
  Unifont для CJK/символов (symbol_map)

**niri border:**
- active `#CECDC3` (fg ink — белая рамка, не accent fill)
- inactive `transparent` (как было)
- urgent `#D14D41` (теперь настоящий red)

**tmux statusline:**
- bar bg `#1C1B1A` fg `#878580`
- session marker bg `#8B7EC8` fg `#100F0F` bold
- current window bg `#8B7EC8` fg `#100F0F` bold
- inactive window fg `#878580`
- pane border `#403E3C`, active `#8B7EC8`
- message bg `#343331` fg `#CECDC3`

**nvim:** vague colors override + custom lualine theme (роли выше).

**quickshell bar:**
- bar bg `#1C1B1A` @ 0.75 (transparent overlay; работает, пока обои тёмные)
- workspace fg `#878580`, active bg `#8B7EC8` fg `#100F0F`, urgent bg `#D14D41` fg `#100F0F`
- empty workspace `#403E3C`
- font: Unifont 11px

**quickshell-greeter:**
- form bg `#1C1B1A` 0.85 over wallpaper
- input bg `#282726`, border `#403E3C`
- focused input border `#8B7EC8`
- button bg `#8B7EC8` fg `#100F0F`

**launcher (quickshell):**
- глиф `Δ` — accent `#8B7EC8`, паре к `λ` на CC
- input текст `#CECDC3`, `>` prompt
- результаты — бокс вниз, цвет = `barBg` (`bg-alt @ 0.75`), square
- selection bg `#8B7EC8`, текст `#100F0F`
- font Terminess Nerd Font Mono 16px (= bar)
- анимации без изменений

**niri (full visuals, square — no rounded corners):**
- border 1px active `#CECDC3` (fg ink, белая), inactive transparent, urgent `#D14D41`
- focus-ring off
- shadow on, color `#00000066`, softness 15, spread 5, offset y6 (тень на
  тёмном — чистый чёрный, не fg-based)
- tab-indicator: top, width 3, gap 6, radius 0, active `#8B7EC8`,
  inactive `#403E3C`, urgent `#D14D41`
- insert-hint `#8B7EC880`
- background-color `#100F0F` (fallback)
- wallpaper: `mntvagaflexoki.png` (Vagabond-горы, инверс-гравюра: штрихи
  muted `#878580` на `#100F0F`; сорс в `wallpapers/`) via swaybg
- geometry-corner-radius 0 + clip-to-geometry (без изменений)
- overview backdrop `#1C1B1A`, workspace-shadow `#00000059` softness 30 offset y8
- layer-rule launcher: radius 0, shadow on

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

**mpv/osc:** фон-элементы `#1C1B1A`, текст `#CECDC3`, акцент `#8B7EC8`

**obsidian:** официальная тема Flexoki из каталога (автор палитры = CEO
Obsidian); кастомный css уходит, vimrc остаётся

**fish/fastfetch:** роли из Base/Accents; директории `#4385BE` (blue),
selection везде bg `#8B7EC8` fg `#100F0F`

**yazi:** как выше, но директории и cwd — `#8B7EC8` (accent, не blue):
purple-forward по просьбе. selection bg `#8B7EC8` fg `#100F0F`
