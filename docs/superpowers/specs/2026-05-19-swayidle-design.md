# swayidle + swaylock + suspend-inhibit CC toggle

**Date:** 2026-05-19
**Machine:** ThinkPad X280, laniakea branch
**Closes:** CONTEXT «System state» — «swayidle установлен но НЕ запущен → экран на батарее не гаснет (дыра №1 по энергии)»

## Goal

Поднять idle-pipeline: dim → lock+screen-off → suspend. Плюс пользовательский toggle в ControlCenter, который блокирует **только** auto-suspend (не весь idle), чтобы можно было оставить машину на длинной задаче без сна, но всё ещё лочить экран.

Один набор таймингов AC = battery (юзер явно выбрал, не разносим).

## Timings

| секунд | действие |
|---|---|
| 300 (5м) | dim — `brightnessctl --save && brightnessctl set 50%-` |
| 600 (10м) | `swaylock -f` + `niri msg action power-off-monitors` (lock и screen-off вместе) |
| 1800 (30м) | `systemctl suspend` |

Resume-hooks:
- 300 → `brightnessctl --restore`
- 600 → `niri msg action power-on-monitors` (swaylock остаётся, юзер видит lock при wake)
- 1800 → нет, logind/swayidle перезапустится при wake естественно.

Always-on hooks:
- `before-sleep 'swaylock -f'` — lock до S3 на любой suspend (lid, idle-timer, ручной `systemctl suspend`). Без этого swaylock рисует уже после wake → промельк рабочего стола.
- `lock 'swaylock -f'` — `loginctl lock-session` → swaylock.

## Why this order (lock+screen-off в одной точке)

Юзер: «зачем lock без screen-off, я же экономлю батарею». Раздельный lock-после-screen-off оставляет окно (между гашением и lock) где экран чёрный, но если кто-то двинет мышь → видит десктоп. Совмещение в 10м закрывает дыру.

Внутри одной timeout-команды `swaylock -f` спавнится первым (рисует overlay), DPMS-off вторым — нет кадра голого десктопа между screen-on и lock-paint.

## Why no AC/battery split

Юзер: «на батарее и питании одинаково». Принято. Дороже в конфиге было бы — два swayidle через udev hooks на power_supply, плюс race на boot. Один процесс с одним конфигом — проще и предсказуемее.

## Suspend-inhibit toggle в CC

### Mechanism

Новый QML singleton `SuspendInhibit.qml`. Состояние `enabled: bool` (true = auto-suspend разрешён, default).

При flip OFF (юзер выключает auto-suspend):
- Spawn background: `systemd-inhibit --mode=block --what=sleep --who=controlcenter --why='manual inhibit' sleep infinity`
- Сохранить PID в свойстве `inhibitPid`.

При flip ON:
- `kill <inhibitPid>` → блокировка снята.

Когда block-инхибит активен:
- `systemctl suspend` от swayidle уходит к logind → видит активный `sleep` block-инхибит → no-op (юнит остаётся, но переход не происходит).
- Lid-close suspend от logind (`HandleLidSwitch=suspend` default) **тоже** блокируется — это та же сущность.
- Lock+screen-off **продолжают работать** — мы блокируем только `sleep`, idle-pipeline до 1800-таймера не трогается.

### Persistence

Состояние НЕ персистится между сессиями — каждый логин начинает с `enabled=true`. Если хочется persistence — отдельный feature later. (YAGNI: toggle нужен на «не уйди в сон пока я компилю», эта потребность сессионная.)

### UI placement

`CcToggleRow` в `ControlCenter.qml`. Label «Auto-suspend». Тот же пиксель-свитч что Airplane/Warm.

Порядок рядов после правки:

| idx | row |
|---|---|
| 0 | Brightness (slider) |
| 1 | Volume (slider) |
| 2 | Airplane (toggle) |
| 3 | Warm (toggle) |
| 4 | **Auto-suspend (toggle)** ← new |
| 5 | BT (list) |
| 6 | Wifi (list) |
| 7 | Output (list) |
| 8 | Power (status) |
| 9 | Footer |

Сдвигает индексы 4..8 → 5..9. `ControlCenter.qml` использует индексы для J/K-nav — потребуется аккуратный re-index. Если в коде есть hard-coded `idx === 4` checks, найти и обновить.

### Cleanup на выход

Используем Quickshell `Process { running: ... }` — qs шлёт SIGTERM компоненту при destruction, что роняет `systemd-inhibit` процесс, что снимает inhibit-lock (lock live только пока systemd-inhibit жив).

🔴 **Если qs убит SIGKILL** (краш, kill -9) — Process не успевает cleanup, `systemd-inhibit` reparent'ится к init и держит lock «навсегда». Симптом: после краша qs новый запуск qs показывает toggle=ON (state не персистится), но реально inhibit ещё висит и suspend не работает. Митигация: `ps -ef | grep systemd-inhibit` — ручной kill сироты. Долгосрочно — `Process.processGroup: true` + kill -- -pgid, либо использовать `systemd-inhibit` с file-descriptor protocol через `loginctl lock` (отложено).

## swaylock styling — Sky Paper + clouds.png

Применяю сам (font/palette exception). Stow-пакет `~/dotfiles/swaylock/.config/swaylock/config`.

Параметры:
- `image=/home/aru/Pictures/wallpapers/clouds.png`, `scaling=fill` — тот же фон что greeter.
- `font=Terminess Nerd Font Mono`, `font-size=14`.
- Индикатор: `ring-color=A8C0D5` (accent-soft), `key-hl-color=4A6F8E` (accent-text), `inside-color=F0EBE0CC` (cream@0.8), `text-color=1F1812` (fg).
- Wrong state: `ring-wrong-color=1F1812` (deep fg, не красный — палитра не имеет красного).
- `ignore-empty-password`, `show-failed-attempts`.
- `indicator-radius=80`, `indicator-thickness=4` — толстое кольцо чтобы читалось на фоне облака.

## File layout

| path | type | purpose |
|---|---|---|
| `~/dotfiles/swayidle/.config/swayidle/config` | stow → `~/.config/swayidle/config` | timeouts + hooks |
| `~/dotfiles/swaylock/.config/swaylock/config` | stow → `~/.config/swaylock/config` | Sky Paper config |
| `~/dotfiles/niri/.config/niri/config.kdl` | edit | `spawn-at-startup "swayidle" "-w"` |
| `~/dotfiles/quickshell/.config/quickshell/SuspendInhibit.qml` | new | singleton (pragma Singleton + qmldir entry) |
| `~/dotfiles/quickshell/.config/quickshell/qmldir` | edit | register `SuspendInhibit` |
| `~/dotfiles/quickshell/.config/quickshell/ControlCenter.qml` | edit | вставить новый CcToggleRow + re-index |

## Startup integration

niri config:
```
spawn-at-startup "swayidle" "-w"
```

Под существующими `spawn-at-startup "qs"` и `spawn-at-startup "swaybg" …`. niri рестартует упавшие spawn-at-startup команды → durability бесплатно, без user systemd-юнита.

## Risk + non-goals

### Risk

- 🔴 **idle-inhibit от mpv/Firefox-fullscreen** — niri поддерживает протокол, swayidle тоже. Должно работать. Но мелкое окно видео в Firefox без full-screen может НЕ inhibit'ить → погаснет через 10м. Принимаем как known limitation, лечится full-screen.
- 🔴 **resume hook на 600 (screen-on)** требует чтобы при wake niri-msg сработал ДО того как юзер увидит. Тестовый риск — на slow-cold systems может быть промельк чёрного перед on. Проверим эмпирически.
- 🔴 **Re-index в ControlCenter.qml** — самый багопрон-чувствительный кусок. Все hard-coded `idx === N` checks (если есть) ломаются. Митигация: grep по файлу перед патчем, переписать через named constants где видно.

### Non-goals (этот заход НЕ делает)

- **Hibernate (S4)** — swap есть (16G), но нужен `resume=UUID=…` в kernel cmdline + `resume` hook в `mkinitcpio.conf` + ребут. Отдельная задача.
- **Suspend-then-hibernate** (hybrid). Зависит от hibernate.
- **idle-inhibitor manual toggle** (для оконного видео) — `wayland-idle-inhibit` как отдельный CC-row. Отложено до запроса.
- **Persistent suspend-inhibit toggle** — сессионный по дизайну.

## Test plan

1. После stow + niri reload: `pgrep -a swayidle` → один процесс с `-w`.
2. `swaylock` standalone: запустить руками, проверить что фон clouds.png и палитра Sky Paper, ввести пароль — unlock.
3. Idle dim: запустить `swayidle -d -w` в терминале (verbose), оставить машину на 5 мин → видеть dim event в логе, экран затемняется.
4. Idle lock+screen-off (10м): экран гаснет, swaylock наложен — двинуть мышь, экран on, swaylock видно, ввести пароль → unlock.
5. Idle suspend (30м): машина уходит в S3, wake → swaylock уже стоит (`before-sleep` сработал).
6. Lid close: закрыть крышку → S3 моментально, открыть → swaylock.
7. CC toggle OFF → idle 30м → НЕ суспендит (lock+screen-off всё равно сработали). Toggle ON → следующий 30м idle уходит в suspend.
8. CC toggle OFF → закрыть крышку → НЕ суспендит (lid тоже блокируется).
9. `loginctl lock-session` из tty → swaylock на niri-сессии.

## CONTEXT updates после имплементации

- «System state»: убрать «swayidle установлен но НЕ запущен → экран на батарее не гаснет (дыра №1 по энергии)».
- Phase 6: пометить swayidle/swaylock как done.
- Stow packages section: добавить `swayidle`, `swaylock`.
- Файлы map: добавить пути.
- Open issues: ничего нового.
- ControlCenter section: ряд Auto-suspend в порядке + краткое описание SuspendInhibit singleton.
