# -*- coding: utf-8 -*-
"""Генератор шпаргалки по биндам: один источник -> HTML + SVG/PNG."""
import io, html, subprocess, sys

# (заголовок секции, где, [(подзаголовок, [(клавиша, описание)...])...], сноска)
DATA = [
("Везде", "keyd", [
  ("Мак-жесты в любом приложении", [
    ("Super+C", "копировать (→ Ctrl+Insert)"),
    ("Super+V", "вставить (→ Shift+Insert)"),
    ("Super+X", "вырезать (→ Shift+Delete)"),
    ("Super+A", "выделить всё"),
    ("Super+Z", "отменить"),
    ("Super+Shift+Z", "вернуть"),
  ]),
  ("Каретка", [
    ("Super+← / →", "начало / конец строки"),
    ("Super+↑ / ↓", "начало / конец документа"),
    ("Alt+← / →", "по словам"),
    ("Alt+Shift+← / →", "выделить по словам"),
  ]),
  ("Модификаторы", [
    ("CapsLock", "Ctrl (удержание)"),
    ("Shift+CapsLock", "настоящий CapsLock"),
    ("левый Ctrl", "смена раскладки us / ru"),
  ]),
], "В терминале Super+Z — это SIGTSTP: подвесит задачу, вернуть fg. Super+S не назначен (Ctrl+S = XOFF)."),

("VSCode", "рабочий Mac", [
  ("Фокус между контейнерами", [
    ("Alt+H / L", "группа левее / правее, сайдбар"),
    ("Alt+J / K", "терминал вниз / редактор вверх"),
    ("Alt+Shift+H / L", "уже / шире"),
    ("Alt+Shift+J / K", "ниже / выше"),
  ]),
  ("Сплиты и вкладки", [
    ("Alt+V / Alt+S", "сплит вправо / вниз"),
    ("Alt+Q", "закрыть редактор / терминал"),
    ("Alt+Z", "развернуть панель"),
    ("Alt+1…9", "вкладка / терминал по номеру"),
    ("Alt+N / P", "следующая / предыдущая"),
    ("Alt+T", "терминал показать / скрыть"),
    ("Alt+Enter", "новый терминал"),
    ("Alt+U", "поиск в терминале"),
    ("Alt+Space", "недавние проекты"),
    ("Alt+R", "перезагрузить окно"),
  ]),
  ("Cmd-ярус", [
    ("Cmd+C / V / X", "копировать / вставить / вырезать"),
    ("Cmd+A", "выделить всё"),
    ("Cmd+Z / Shift+Z", "отменить / вернуть"),
    ("Cmd+S", "сохранить"),
  ]),
  ("Проводник — hjkl как в vim", [
    ("J / K", "вниз / вверх"),
    ("H / L", "свернуть / развернуть"),
    ("gg / G", "в начало / в конец"),
    ("O", "открыть"),
    ("Alt+V", "открыть сбоку"),
    ("A / Shift+A", "новый файл / папка"),
    ("R / Shift+R", "переименовать / обновить"),
    ("D / Shift+D", "удалить / в корзину"),
    ("Y / X / P", "копировать / вырезать / вставить"),
    ("Shift+Y", "скопировать путь"),
    ("V", "пометить для мультивыбора"),
    ("Esc", "назад в редактор"),
  ]),
  ("Списки и подсказки", [
    ("Ctrl+J / K", "вниз / вверх в quick-open и автодополнении"),
  ]),
], "Весь Ctrl-ярус readline (a e k u w y p n r t f g d l v x) проброшен во встроенный терминал как есть."),

("Терминал", "kitty + fish", [
  ("Буфер обмена", [
    ("Super+C / V", "копировать / вставить"),
    ("Ctrl+Shift+C / V", "то же, через ssh"),
    ("Ctrl+Shift+S", "вставить первичное выделение"),
    ("Ctrl+Shift+O", "выделение в программу"),
  ]),
  ("Прокрутка kitty", [
    ("Ctrl+Shift+K / J", "на строку вверх / вниз"),
    ("Ctrl+Shift+PgUp / PgDn", "на страницу"),
    ("Ctrl+Shift+Home / End", "в начало / конец"),
    ("Ctrl+Shift+H", "весь буфер в пейджере"),
  ]),
  ("Строка команды — fish", [
    ("Ctrl+A / E", "начало / конец строки"),
    ("Ctrl+U", "стереть строку целиком"),
    ("Ctrl+K", "стереть до конца"),
    ("Ctrl+W", "стереть путь по компоненту"),
    ("Ctrl+Y", "вставить стёртое"),
    ("Ctrl+D", "стереть символ вперёд — не выход"),
    ("Ctrl+P / N", "история назад / вперёд"),
    ("Ctrl+L", "очистить экран"),
    ("→ / Ctrl+F", "принять автоподсказку"),
  ]),
  ("fzf", [
    ("Ctrl+T", "файлы"),
    ("Ctrl+R", "история команд"),
    ("Ctrl+G", "перейти в каталог"),
  ]),
], None),

("nvim", "leader = Space", [
  ("Alt-ярус — общий с VSCode и tmux", [
    ("Alt+H / J / K / L", "фокус сплита; на краю уходит в tmux"),
    ("Alt+Shift+H/J/K/L", "размер сплита"),
    ("Alt+V / Alt+S", "сплит вправо / вниз"),
    ("Alt+Q", "закрыть сплит / панель"),
    ("Alt+T", "терминал показать / скрыть"),
  ]),
  ("Файлы и поиск", [
    ("Space Space", "найти файл"),
    ("Space /", "grep по проекту"),
    ("Space ,", "переключить буфер"),
    ("Space :", "история команд"),
    ("Space f f / f r", "файлы / недавние"),
    ("Space f g / f b", "grep / открытые буферы"),
    ("Space f s / f h", "символы / help"),
    ("Space f k", "все бинды"),
    ("Space n", "дерево файлов"),
    ("Space e", "фокус дерево ↔ файл"),
    ("Space d", "стартовый экран"),
  ]),
  ("Дерево файлов", [
    ("l / h", "войти / закрыть"),
    ("L / H", "корень внутрь / наверх"),
    ("y / x / p", "копировать / вырезать / вставить"),
    ("v", "пометить для мультивыбора"),
    ("Alt+V / Alt+S", "открыть в сплит"),
  ]),
  ("Буферы и вкладки", [
    ("Shift+L / Shift+H", "следующий / предыдущий буфер"),
    ("Space b b / b d", "список / закрыть"),
    ("Space b o", "закрыть все прочие"),
    ("Space 1…9 / 0", "вкладка по номеру / последняя"),
    ("Space w / Space q", "сохранить / закрыть буфер"),
  ]),
  ("Код — LSP", [
    ("gd / gr", "определение / ссылки"),
    ("K", "документация"),
    ("Space c r / c a", "переименовать / действие"),
    ("Space c f / c d", "форматировать / диагностика"),
    ("[d / ]d", "предыдущая / следующая проблема"),
    ("Space x x / x w", "проблемы файла / проекта"),
    ("Space x q", "quickfix"),
  ]),
  ("Git", [
    ("[c / ]c", "предыдущий / следующий hunk"),
    ("Space g p / g r", "показать / откатить hunk"),
    ("Space g b", "blame строки"),
    ("Space g d / g q", "открыть / закрыть diff"),
    ("Space g h / g H", "история файла / репозитория"),
  ]),
  ("Правка", [
    ("Ctrl+A", "выделить всё"),
    ("+ / −", "число больше / меньше"),
    ("Esc", "снять подсветку поиска"),
    ("( [ { \" ' `", "в выделении — обернуть"),
    ("p", "в выделении — вставить, не затирая регистр"),
  ]),
  ("Сессии", [
    ("Space s s / s l", "восстановить для каталога / последнюю"),
    ("Space s d", "не сохранять эту"),
  ]),
], None),

("tmux", "без префикса", [
  ("Пейны", [
    ("Alt+H / J / K / L", "фокус; внутри nvim уходит в nvim"),
    ("Alt+Shift+H/J/K/L", "размер"),
    ("Alt+V / Alt+S", "сплит вправо / вниз"),
    ("Alt+Q", "закрыть пейн"),
    ("Alt+Z", "развернуть на всё окно"),
  ]),
  ("Окна и сессии", [
    ("Alt+Enter", "новое окно"),
    ("Alt+1…9", "окно по номеру"),
    ("Alt+N / P", "следующее / предыдущее"),
    ("Alt+Space", "переключатель сессий (sesh)"),
    ("Alt+D", "отцепиться"),
    ("Alt+Shift+Q", "убить сессию (с подтверждением)"),
    ("Alt+R", "перечитать конфиг"),
  ]),
  ("Copy-mode — vi", [
    ("Alt+U", "войти / выйти"),
    ("Alt+/ · Alt+?", "искать вниз / вверх"),
    ("v", "начать выделение"),
    ("y · Super+C", "копировать и выйти"),
    ("q", "выйти"),
    ("колесо", "двигает курсор, выделение тянется"),
  ]),
], "Всё перечисленное — без префикса. Префикс остался дефолтным Ctrl+B и почти не нужен."),

("niri", "Mod = Super", [
  ("Запуск", [
    ("Mod+Enter", "терминал"),
    ("Mod+D", "лаунчер"),
    ("Mod+E", "файловый менеджер"),
    ("Mod+Space", "центр управления"),
    ("Mod+Shift+E", "меню питания"),
    ("Super+Alt+L", "заблокировать экран"),
  ]),
  ("Фокус", [
    ("Mod+H / J / K / L", "колонка / окно по направлению"),
    ("Mod+Home / End", "первая / последняя колонка"),
    ("Mod+1…9", "воркспейс"),
    ("Mod+O", "обзор"),
  ]),
  ("Перемещение", [
    ("Mod+Shift+H/J/K/L", "двигать колонку / окно"),
    ("Mod+Ctrl+Home / End", "колонку в начало / конец"),
    ("Mod+Shift+1…9", "окно на воркспейс"),
    ("Mod+[ / ]", "втянуть / вытолкнуть вбок"),
    ("Mod+, / Mod+.", "втянуть в колонку / выкинуть"),
  ]),
  ("Размер и вид", [
    ("Mod+R / Mod+Shift+R", "ширина по пресетам вперёд / назад"),
    ("Mod+Ctrl+Shift+R", "высота по пресетам"),
    ("Mod+Ctrl+R", "сбросить высоту"),
    ("Mod+− / Mod+=", "ширина −10% / +10%"),
    ("Mod+Shift+− / =", "высота −10% / +10%"),
    ("Mod+F / Mod+Shift+F", "развернуть колонку / полный экран"),
    ("Mod+M", "окно до краёв"),
    ("Mod+Ctrl+F", "колонка на всю ширину"),
    ("Mod+Shift+C", "центрировать колонку"),
    ("Mod+Ctrl+C", "центрировать видимые"),
    ("Mod+W", "колонка вкладками"),
    ("Mod+G / Mod+Shift+G", "плавающее / фокус туда-обратно"),
  ]),
  ("Прочее", [
    ("Mod+Q", "закрыть окно"),
    ("Mod+Shift+/", "подсказка по биндам"),
    ("Mod+Escape", "отдать бинды приложению"),
    ("Mod+Shift+P", "погасить мониторы"),
    ("Print", "снимок области"),
    ("Ctrl+Print / Alt+Print", "снимок экрана / окна"),
    ("XF86-клавиши", "громкость, яркость, медиа — и на замке"),
  ]),
], None),
]

TITLE = "Бинды"
LEDE  = ("Единая схема: Linux-машины (niri + kitty + tmux + nvim) и рабочий Mac (VSCode). "
         "Два яруса — Alt ходит между контейнерами, Super/Cmd — системный слой. "
         "Спецификация: docs/keybinds.md")

def rows_count():
    return sum(len(rs) for _,_,subs,_ in DATA for _,rs in subs)

# ---------------------------------------------------------------- SVG / PNG
COLS      = 3
COL_W     = 780
GAP       = 46
MARGIN    = 54
KEY_W     = 300
ROW_H     = 27
SUB_H     = 42
SEC_H     = 58
NOTE_H    = 26
FS_ROW    = 15.5
FS_SUB    = 15
FS_SEC    = 27
FS_NOTE   = 13
FONT_S    = "Noto Sans"
FONT_M    = "Noto Sans Mono"

def e(t): return html.escape(str(t), quote=True)

def build_blocks():
    """Блок = один подзаголовок с его строками; секция может переноситься."""
    blocks = []
    for sec, where, subs, note in DATA:
        for i, (sub, rows) in enumerate(subs):
            blocks.append({
                'sec': sec, 'where': where, 'sub': sub, 'rows': rows,
                'first': i == 0,
                'note': note if i == len(subs) - 1 else None,
            })
    return blocks

def block_h(b, with_sec):
    h = SUB_H + ROW_H * len(b['rows'])
    if with_sec: h += SEC_H
    if b['note']: h += NOTE_H
    return h

def _pack(blocks, maxh):
    """Разложить по колонкам, не превышая maxh. None если не влезло в COLS."""
    cols, cur, curh, prev_sec = [], [], 0.0, None
    for b in blocks:
        need_sec = b['first'] or (prev_sec != b['sec'])
        h = block_h(b, need_sec)
        if cur and curh + h > maxh:
            if len(cols) == COLS - 1:
                return None
            cols.append(cur); cur, curh, prev_sec = [], 0.0, None
            need_sec = True; h = block_h(b, True)
            if h > maxh:
                return None
        b['_sec'] = need_sec
        b['_cont'] = need_sec and not b['first']
        cur.append(b); curh += h; prev_sec = b['sec']
    cols.append(cur)
    return cols

def layout(blocks):
    # _pack мутирует флаги _sec/_cont прямо в блоках, поэтому неудачные попытки
    # бинарного поиска затирают разметку удачной. Ищем только высоту, а финальную
    # укладку прогоняем ею заново — тогда флаги соответствуют результату.
    total = sum(block_h(b, True) for b in blocks)
    lo, hi, best_h = 1, int(total) + 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if _pack(blocks, mid) is not None:
            best_h = mid; hi = mid - 1
        else:
            lo = mid + 1
    return _pack(blocks, best_h if best_h is not None else total)

def svg():
    blocks = build_blocks()
    cols = layout(blocks)
    head_h = MARGIN + 46 + 30 + 24
    body_h = max(sum(block_h(b, b['_sec']) for b in c) for c in cols)
    W = MARGIN * 2 + COL_W * COLS + GAP * (COLS - 1)
    H = int(head_h + body_h + MARGIN)
    o = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    o.append(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
    o.append(f'<text x="{MARGIN}" y="{MARGIN+34}" font-family="{FONT_S}" font-size="38" '
             f'font-weight="700" fill="#000">{e(TITLE)}</text>')
    o.append(f'<text x="{MARGIN}" y="{MARGIN+66}" font-family="{FONT_S}" font-size="14.5" '
             f'fill="#555">{e(LEDE)}</text>')
    o.append(f'<line x1="{MARGIN}" y1="{MARGIN+82}" x2="{W-MARGIN}" y2="{MARGIN+82}" '
             f'stroke="#000" stroke-width="1.4"/>')

    for ci, col in enumerate(cols):
        x = MARGIN + ci * (COL_W + GAP)
        y = head_h
        for b in col:
            if b['_sec']:
                y += 34
                label = b['sec'] + (" (продолжение)" if b['_cont'] else "")
                o.append(f'<text x="{x}" y="{y}" font-family="{FONT_S}" font-size="{FS_SEC}" '
                         f'font-weight="700" fill="#000">{e(label)}</text>')
                if not b['_cont']:
                    o.append(f'<text x="{x+COL_W}" y="{y}" text-anchor="end" font-family="{FONT_S}" '
                             f'font-size="13.5" fill="#666">{e(b["where"])}</text>')
                y += 12
                o.append(f'<line x1="{x}" y1="{y}" x2="{x+COL_W}" y2="{y}" stroke="#000" stroke-width="1.2"/>')
                y += SEC_H - 46
            y += 27
            o.append(f'<text x="{x}" y="{y}" font-family="{FONT_S}" font-size="{FS_SUB}" '
                     f'font-weight="700" fill="#333">{e(b["sub"])}</text>')
            y += SUB_H - 27
            for k, d in b['rows']:
                y += 19
                o.append(f'<text x="{x}" y="{y}" font-family="{FONT_M}" font-size="{FS_ROW}" '
                         f'fill="#000">{e(k)}</text>')
                o.append(f'<text x="{x+KEY_W}" y="{y}" font-family="{FONT_S}" font-size="{FS_ROW}" '
                         f'fill="#222">{e(d)}</text>')
                y += ROW_H - 19
                o.append(f'<line x1="{x}" y1="{y-6}" x2="{x+COL_W}" y2="{y-6}" stroke="#e6e6e6" stroke-width="1"/>')
            if b['note']:
                y += 18
                o.append(f'<text x="{x+6}" y="{y}" font-family="{FONT_S}" font-size="{FS_NOTE}" '
                         f'fill="#666">{e(b["note"])}</text>')
                y += NOTE_H - 18
    o.append('</svg>')
    return '\n'.join(o)

# ---------------------------------------------------------------- HTML
def html_doc():
    p = []
    p.append('<!doctype html>\n<meta charset="utf-8">\n<title>Бинды</title>')
    p.append('''<style>
  @page { size: A4 portrait; margin: 12mm 10mm; }
  * { box-sizing: border-box; }
  body { font: 9.5pt/1.35 "Noto Sans", -apple-system, sans-serif; color:#000; background:#fff;
         margin:0; padding:0 0 8mm; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  h1 { font-size:15pt; font-weight:600; margin:0 0 1mm; }
  .lede { font-size:8pt; color:#444; margin:0 0 5mm; padding-bottom:3mm; border-bottom:1px solid #000; }
  .cols { columns:2; column-gap:8mm; }
  section { break-inside:avoid; margin:0 0 4.5mm; }
  h2 { font-size:10.5pt; font-weight:600; margin:0 0 1.5mm; padding-bottom:.8mm; border-bottom:1px solid #000; }
  h2 .where { font-size:7.5pt; font-weight:400; color:#555; float:right; padding-top:1.5pt; }
  h3 { font-size:8pt; font-weight:600; text-transform:uppercase; letter-spacing:.06em; color:#333; margin:2.5mm 0 1mm; }
  table { width:100%; border-collapse:collapse; }
  td { padding:.5mm 0; vertical-align:top; border-bottom:1px solid #e0e0e0; }
  tr:last-child td { border-bottom:0; }
  td.k { width:42%; padding-right:2mm; font-family:"Noto Sans Mono",monospace; font-size:8.5pt; white-space:nowrap; }
  td.d { color:#222; }
  .note { font-size:7.5pt; color:#555; margin:1.5mm 0 0; padding-left:2mm; border-left:2px solid #ccc; }
  @media screen { body { max-width:210mm; margin:0 auto; padding:10mm; } }
</style>''')
    p.append(f'\n<h1>{e(TITLE)}</h1>')
    p.append(f'<p class="lede">{e(LEDE)}</p>')
    p.append('\n<div class="cols">\n')
    for sec, where, subs, note in DATA:
        p.append('<section>')
        p.append(f'  <h2>{e(sec)} <span class="where">{e(where)}</span></h2>')
        for sub, rows in subs:
            p.append(f'  <h3>{e(sub)}</h3>')
            p.append('  <table>')
            for k, d in rows:
                p.append(f'    <tr><td class="k">{e(k)}</td><td class="d">{e(d)}</td></tr>')
            p.append('  </table>')
        if note:
            p.append(f'  <p class="note">{e(note)}</p>')
        p.append('</section>\n')
    p.append('</div>')
    return '\n'.join(p)

if __name__ == '__main__':
    out_svg, out_png, out_html = sys.argv[1], sys.argv[2], sys.argv[3]
    io.open(out_svg, 'w', encoding='utf-8').write(svg())
    io.open(out_html, 'w', encoding='utf-8').write(html_doc())
    subprocess.run(['rsvg-convert', '-o', out_png, out_svg], check=True)
    print(f'строк-биндов: {rows_count()}')
