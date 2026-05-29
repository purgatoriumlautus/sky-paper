# Palette — Sky Paper (Ghibli warm cream + cool sky)

Тёплый кремовый фон, два sky-accent'а — мягкий для UI-заливок, тёмный для текста/синтаксиса. Painterly Ghibli vibe (см. `~/Pictures/wallpapers/clouds.png`). Высокий контраст основного текста.

**Источник:** custom, 2026-05-17. Третья итерация (после dark Cool Mono → light Cool Paper → Sky Paper).

**Шрифт:** GNU Unifont, bitmap 16px.

---

## Base

| role | hex | RGB | контраст к bg | назначение |
|---|---|---|---|---|
| **bg** | `#F0EBE0` | (240,235,224) | — | тёплый кремовый, cloud highlight |
| bg-alt | `#E4DED0` | (228,222,208) | — | bars / panels / line / gutter |
| border-dim | `#C5BFB5` | (197,191,181) | 1.4:1 | inactive borders, separators |
| muted | `#7A716A` | (122,113,106) | 4.7:1 | комменты, inactive text |
| **fg** | `#1F1812` | (31,24,18) | **15:1** | основной текст, extreme readability |
| **accent-soft** | `#A8C0D5` | (168,192,213) | 1.7:1 | sky — для UI fills (borders, button bg) |
| **accent-text** | `#4A6F8E` | (74,111,142) | 5.5:1 | deep sky — для текста (syntax, links) |
| accent-text-bright | `#5C84A4` | (92,132,164) | 4.6:1 | brighter sky — sibling-hue для func/builtin (vs keyword) |
| accent-warm | `#8B6F4E` | (139,111,78) | 5.0:1 | warm clay — string/number литералы, escape muted=comment trap |

Два accent'а потому что одного **не хватает**: один и тот же sky `#A8C0D5` нечитаем как цвет текста на cream bg (1.7:1), но идеален как заливка/рамка. `#4A6F8E` — та же hue, в 2× темнее → читается как keyword/link.

---

## Syntax (nvim)

| role | hex | rationale |
|---|---|---|
| Normal fg | `#1F1812` | extreme dark |
| Comment | `#7A716A` italic | dim, читаемо |
| Keyword/Statement/Conditional | `#4A6F8E` | deep sky — control flow |
| Type/Class | `#1F1812` bold | weight = structural noun |
| Function/Builtin | `#5C84A4` | brighter sky — verb, sibling-hue Keyword |
| String | `#8B6F4E` | warm clay — литерал, не путать с comment |
| Number/Boolean | `#8B6F4E` | warm clay — literal data |
| Constant | `#1F1812` bold | weight = structural |
| Operator | `#1F1812` | fg (был muted = читалось как comment) |
| Property/Parameter | `#1F1812` | = fg |

## Diagnostics

| role | hex | note |
|---|---|---|
| error | `#4A6F8E` | bold + underline |
| warning | `#7A716A` | italic |
| hint | `#7A716A` | |
| ok/plus | `#1F1812` | bold |
| delta | `#7A716A` | |

---

## Terminal 16-color (kitty)

| idx | ANSI | hex | note |
|---|---|---|---|
| 0 | black | `#1F1812` | fg |
| 1 | red | `#1F1812` | mono (errors via bold) |
| 2 | green | `#1F1812` | fg (success) |
| 3 | yellow | `#7A716A` | muted |
| 4 | blue | `#4A6F8E` | deep sky |
| 5 | magenta | `#4A6F8E` | deep sky |
| 6 | cyan | `#4A6F8E` | deep sky |
| 7 | white | `#F0EBE0` | bg |
| 8 | br black | `#7A716A` | muted |
| 9 | br red | `#1F1812` | fg |
| 10 | br green | `#1F1812` | fg |
| 11 | br yellow | `#7A716A` | muted |
| 12 | br blue | `#5C84A4` | brighter deep sky |
| 13 | br magenta | `#5C84A4` | brighter deep sky |
| 14 | br cyan | `#5C84A4` | brighter deep sky |
| 15 | br white | `#FFFFFF` | pure white |

---

## Per-tool

**kitty:**
- bg `#F0EBE0`, fg `#1F1812`
- cursor `#4A6F8E` (accent-text, видимый)
- selection bg `#C5BFB5`, fg `#1F1812`
- url `#4A6F8E`
- active border `#A8C0D5`, inactive `#C5BFB5`, bell `#1F1812`
- active tab bg `#A8C0D5` fg `#1F1812`
- inactive tab bg `#E4DED0` fg `#7A716A`
- font: Unifont 12pt

**niri border:**
- active `#A8C0D5` (sky fill)
- inactive `transparent` (убрано)
- urgent `#1F1812` (dark)

**tmux statusline:**
- bar bg `#E4DED0` fg `#7A716A`
- session marker bg `#A8C0D5` fg `#1F1812` bold
- current window bg `#A8C0D5` fg `#1F1812` bold
- inactive window fg `#7A716A`
- pane border `#C5BFB5`, active `#A8C0D5`
- message bg `#C5BFB5` fg `#1F1812`

**nvim:** vague colors override + custom lualine theme.

**waybar:**
- bar bg `#E4DED0` 0.85 (transparent overlay)
- workspace fg `#7A716A`, active bg `#A8C0D5` fg `#1F1812`, urgent bg `#1F1812` fg `#F0EBE0`
- empty workspace `#C5BFB5`
- font: Unifont 11px

**regreet:**
- form bg `#F0EBE0` 0.85 over wallpaper
- input bg `#E4DED0`, border `#C5BFB5`
- focused input border `#A8C0D5`
- button bg `#A8C0D5` fg `#1F1812`

**launcher (quickshell, заменил tofi 2026-05-21):**
- глиф `Δ` (accent-text `#4A6F8E`) — на баре по центру, паре к `λ` на CC
- input на баре (прозрачный ряд поверх ушедших часов), `>` prompt, текст `#1F1812`
- результаты — отдельный бокс ВНИЗ под баром, цвет = `barBg` (`bgAlt @ 0.75`),
  без рамки, square (читается как продолжение бара)
- selection bg `#A8C0D5`, текст `#1F1812`
- font Terminess Nerd Font Mono 16px (= bar)
- анимация: `Δ` едет из центра влево, prompt+input fade-in, список растёт вниз (макс 5)

**niri (full visuals, square — no rounded corners):**
- border 2px active `#A8C0D5`, inactive transparent, urgent `#1F1812`
- focus-ring off
- shadow on, color `#1F181240`, softness 24, spread 2, offset y6
- tab-indicator: place-within-column top, width 3, gap 6, **radius 0**, active `#A8C0D5`, inactive `#C5BFB5`, urgent `#1F1812`
- insert-hint `#A8C0D580`
- background-color `#F0EBE0` (fallback)
- window-rule **geometry-corner-radius 0** + clip-to-geometry (no-op at 0 but kept)
- overview backdrop `#E4DED0`, workspace-shadow `#1F181233` softness 30 offset y8
- layer-rule launcher: **radius 0**, shadow on
