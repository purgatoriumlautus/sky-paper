# Journal 2026 — laniakea (archived)

Archived session journal (2026). This is the entire pre-2026-07-11 CONTEXT.md, kept verbatim for history.
Superseded by the new manifest-style CONTEXT.md on 2026-07-11 (see docs/superpowers/specs/2026-07-11-repo-structure-design.md).

---

# CONTEXT — laniakea (ThinkPad X280)

System manifest for Claude. Loaded automatically when working in `~/dotfiles/` (via `CLAUDE.md` → `@CONTEXT.md`).

Last updated: **2026-05-24** (**zathura — Sky Paper PDF/ePub/CBZ viewer**: stow `zathura/` с `zathurarc` под палитру, mupdf-бэкэнд, `install.sh` ставит pkg + xdg-mime default'ы (PDF/ePub/XPS/CBZ); yazi: `keymap.toml` появился — `<Esc>` мапится на `leave` (родительский dir, как `h`); `.stow-local-ignore` добавлен в `yazi/` и `zathura/` (без него `install.sh`/`CHEATSHEET.txt` утекают симлинками в `$HOME` — stow-built-in defaults игнорят только `README.*`, локальный ignore их **заменяет**, поэтому в файле репродуцируется полный stow-дефолт + локальные правила). — Раньше 2026-05-21: **qs-native launcher заменил tofi** — `Launcher.qml` + `AppLauncher.qml` singleton в резидентном `qs` (нет cold-start); `Δ`-глиф на баре, clock fade → input на баре → результаты вниз как продолжение бара; apps fuzzy+frecency / calc / run; tofi снесён (stow+symlink+pkg). Также: лок стал **clock-first** (виден сразу, asleep только после 10-мин idleTimer — как greeter); fontconfig — Terminess AA-off **только на нативных размерах** (фикс битых глифов в Obsidian). Всё смержено в `laniakea`. — Раньше 2026-05-20: **Quickshell screen locker заменил swaylock** — `LockScreen.qml`/`LockBox.qml`/`LockClock.qml` через `WlSessionLock` + `PamContext`; greeter зеркалит state-machine; swaylock снесён; ранее — TLP 85/90 + CC EPP cycler; накануне — swayidle, security hardening, keyd CapsLock→F19)

Companion machine to **celestia** (desktop, master branch). This is **laniakea** (laptop, branch `laniakea`).

---

## Machine

- ThinkPad X280, Intel 8th gen i5/i7, UHD 620 iGPU
- 16GB RAM, 238GB NVMe
- Display: eDP-1, 1920×1080 FHD, 12.5", scale=1 in niri
- Hostname: `laniakea`

## System state (verified 2026-05-18)

- Arch Linux, kernel 7.0.8-arch
- Shell: **fish 4.7.1 — УЖЕ дефолтный login shell** (`getent passwd aru` → `/usr/bin/fish`). Старый CONTEXT про «возможно ещё bash» устарел.
- niri запускается через **greetd + quickshell-greeter** (cage, VT1). regreet **полностью удалён** (пакет greetd-regreet + xorg-xwayland снесены, конфиги/`.bak` стёрты). cage помечен `--asexplicit` (greeter на нём держится). Если когда-нибудь нужны X11-приложения под niri → ставить `xwayland-satellite` отдельно.
- NetworkManager + iwd оба active+enabled (дублирование — выбрать одну схему, pending)
- tlp active+enabled. `/etc/tlp.conf` сам **не тронут** — оверрайды через drop-in `/etc/tlp.d/00-aru.conf` (**START/STOP_CHARGE_THRESH_BAT0=85/90**, установлено+верифицировано: `/sys/.../charge_control_*_threshold` = 85/90). EPP defaults НЕ переопределяли (TLP-дефолт `balance_performance` AC / `balance_power` BAT). См. секцию «🔋 Session 2026-05-19 — TLP + CC EPP».
- swayidle 1.9.0 запущен (niri `spawn-at-startup "swayidle" "-w"`). Lock делает **встроенный Quickshell-локер** (`LockScreen.qml` в `~/dotfiles/quickshell/.config/quickshell/`) через `WlSessionLock` + `PamContext`, триггерится `qs ipc call lock lock`. swayidle/niri/`loginctl lock-session` — все три пути на IPC. Бинарь `swaylock` в системе оставлен (на всякий), stow-пакет `swaylock/` снесён. См. секции «🌙 Session 2026-05-19 — swayidle» и «🔒 Session 2026-05-20 — Quickshell lock screen» ниже.
- xdg-desktop-portal: **gtk** (cosmic снесён 2026-05-21 — был лишний для niri; niri зависит от виртуального `xdg-desktop-portal-impl`, который gtk и так предоставляет). file-picker / screen-share идут через gtk.

## 🔒 Session 2026-05-19 (late) — security hardening: nftables + sshd

**Решение Арса:** laptop был с открытым sshd на `0.0.0.0:22` (`PasswordAuthentication yes`) и **без файрвола** — починить за 1ч.

### Найдено
- `sshd` active+enabled, `PasswordAuthentication yes`, **нет `~/.ssh/`** вовсе → password-only SSH в мир.
- `nftables` установлен, но disabled/inactive. Ни firewalld, ни ufw.
- **Mystery listener `0.0.0.0:27500`** = `passimd` (Richard Hughes' LAN-cache для firmware metadata, optdep fwupd). Не игра, но `pacman -Rns passim` ломает fwupd (hard dep на libpassim.so) → **masked** через `systemctl mask passim.service` (D-Bus/socket-activated, no `[Install]`, нельзя disable). `ss -tlnp` подтверждает — :27500 ушёл.
- 35 пакетов-сирот (`pacman -Qtdq`) удалены: build tools (cmake/meson/ninja — pacman re-pull'нет как makedepends при необходимости), `*-debug`, `accountsservice` (был нужен GDM/LightDM, у нас greetd), Xorg bits (значит XWayland НЕ установлен — если когда-нибудь нужны X11-apps под niri, `xwayland-satellite` отдельно). Освободило ~209 MiB.

### nftables — `~/dotfiles/nftables/`
- Layout: `etc/nftables.conf` (entry: `flush ruleset` + `include "/etc/nftables.d/*.nft"`) + `etc/nftables.d/00-filter.nft` (правила) + `install.sh`. **НЕ stow** — root-owned `/etc/`, та же логика что keyd/quickshell-greeter (бэкап `.bak`, `nft -c -f` валидация перед `systemctl reload`).
- inet family (v4+v6 в одной таблице). Policy drop input + drop forward (Docker re-add'нет свои forward'ы в iptables-nft chain'е), accept output.
- 🔴 **DHCP allow ДОЛЖЕН быть до `ct state invalid drop`.** DHCP-replies классифицируются INVALID (src `0.0.0.0`, broadcast dst, conntrack не успевает) → если ниже invalid-drop, тихо ломается при следующем renewal. Правила: `udp sport 67 dport 68 accept` + `udp sport 547 dport 546` (v6).
- 🔴 **`pkttype host` в reject-rule** — исключает broadcast/multicast → mDNS/SSDP падают в policy drop тихо, без reject (нет risk reflection-amplification). `limit rate 5/s burst 5` гейтит сам reject — что выше лимита тоже падает в drop.
- `iif lo accept` + counter в конце цепочки («fell through to policy drop» — видно в `nft list ruleset`).
- **Закомментировано** до явной нужды: `iif "virbr0" accept` (для libvirt VM→host), `tcp dport 22 accept` (inbound ssh).
- mDNS/Avahi (UDP 5353 multicast) **не разрешён** — если понадобятся принтер-дискавери / `.local` хосты, добавить `udp dport 5353 accept`.

### sshd hardening — `~/dotfiles/sshd/`
- Drop-in `etc/ssh/sshd_config.d/00-hardening.conf` (не редактируем `/etc/ssh/sshd_config` — `Include /etc/ssh/sshd_config.d/*.conf` уже там). У sshd **first-obtained-value-wins**: побеждает первое прочитанное значение. Поэтому `00-` префикс ставит наш файл первым среди drop-in'ов → наши значения имеют приоритет. (Раньше был `99-` — сортировал нас последними, т.е. любой чужой drop-in переопределял бы hardening; переименовано 2026-07-02, install.sh чистит старое имя.)
- Effective (через `sshd -T`): `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `PermitEmptyPasswords no`, `X11Forwarding no`.
- 🔴 **Inbound SSH на laniakea сейчас невозможен** — key-only + `~/.ssh/authorized_keys` отсутствует. Если когда-нибудь захочется коннектиться извне → `ssh-copy-id` с другой машины ДО включения этого. Для outbound (laniakea → куда-то) ничего не меняется.
- `install.sh` делает `sshd -t` валидацию + `systemctl reload sshd` (existing sessions выживают).

### sysctl hardening — `~/dotfiles/sysctl/`
- Drop-in `etc/sysctl.d/99-hardening.conf` + `install.sh` + `README.md`. Перенесено с `dotfiles_pc/`, **`ip_forward` закомментирован** (laptop, no Docker/libvirt → дефолт 0).
- **Не пересекается с nftables, дополняет:** nftables = packet filter на netfilter-хуках; sysctl = kernel-knobs, которые firewall не достаёт. Конкретно: `accept_redirects=0` (nftables «пропустил» бы ICMP-redirect — kernel всё равно применил бы маршрут; гасится только sysctl'ом), `kptr_restrict=1` (не сеть вовсе — local KASLR-bypass), `rp_filter=1` (anti-spoof на стороне kernel-route-lookup, дешевле чем nft-правило), `tcp_syncookies=1` (TCP-stack поведение, не filter), `send_redirects=0`.
- `install.sh`: `install -m 644` в `/etc/sysctl.d/` + `sysctl --system` (применяется немедленно, без reboot).

## 🌙 Session 2026-05-19 — swayidle + swaylock + Auto-suspend CC toggle

**Решение Арса:** закрыть «дыру №1 по энергии» — экран на батарее не гас. Idle-pipeline + lock + toggle авто-suspend'а из CC.

- **Спека:** `docs/superpowers/specs/2026-05-19-swayidle-design.md` (docs/ в .gitignore — только локально).
- **swayidle** stow-пакет `~/dotfiles/swayidle/.config/swayidle/{config,README.md}` → `~/.config/swayidle/`. Timeline (один набор AC=battery, Арс выбрал): **300с dim** (`brightnessctl --save && set 50%-` / resume restore) → **600с lock+screen-off вместе** (`swaylock -f; niri msg action power-off-monitors` / resume `power-on-monitors`, swaylock остаётся) → **1800с `systemctl suspend`**. Плюс `before-sleep 'swaylock -f'` (lock ДО любого сна — нет промелька десктопа при wake) + `lock 'swaylock -f'` (loginctl).
- 🔴 **swayidle НЕ поддерживает `\` line-continuation** — backslash → `wordexp syntax error на line N`, демон не стартует. Каждая `timeout … resume …` директива одной физической строкой. Проверено эмпирически (`swayidle -w -C <file>` валидирует парс, Ctrl-C). Зафиксировано в комменте конфига + README.
- **swaylock** stow-пакет `~/dotfiles/swaylock/.config/swaylock/{config,README.md}` → `~/.config/swaylock/`. Sky Paper + `clouds.png` scaling=fill = зеркало quickshell-greeter (lock и login = одна поверхность). Terminess 14, ring `#A8C0D5`, key-hl `#4A6F8E`, inside `#F0EBE0CC`, wrong = deep fg `#1F1812` (палитра без красного). Цвета руками синхронны с PALETTE.md — нет shared theme через бинарь swaylock. Запускается swayidle'ом и niri `Mod+Alt+L`.
- **Запуск:** niri `spawn-at-startup "swayidle" "-w"` (под `qs`/`swaybg`). niri рестартует упавший процесс — без user systemd-юнита.
- **CC Auto-suspend toggle:** singleton `SuspendInhibit.qml` (`enabled:true` = suspend разрешён, session-scoped, НЕ персистится). OFF → Quickshell `Process{running:true}` держит `systemd-inhibit --mode=block --what=sleep --who=controlcenter sleep infinity` → logind no-op'ит `systemctl suspend` от swayidle **И** lid-close suspend; dim+lock+screen-off продолжают работать (блокируем только `sleep`, не весь idle). ON → Process `running=false` → SIGTERM → lock снят. Механизм проверен: `systemd-inhibit --list` показывает block пока процесс жив, релиз при выходе. 🔴 SIGKILL qs → systemd-inhibit reparent к init, lock висит «навсегда» → `ps -ef|grep systemd-inhibit` + ручной kill.
- **CC re-index:** новый ряд idx 4 «Auto-suspend» (`CcToggleRow`, пиксель-свитч как Airplane/Warm). Сдвинул BT 4→5, Wifi 5→6, Output 6→7, Power 7→8, Footer 8→9. `rowCount` 9→10. Обновлены `dispatchHL`/`handleEnter`/`listLen`/`openList`/`commitList`/Connections-`openRow`-чеки + хедер-коммент. qs live-reload **чист** (ноль warnings). Лёг чисто с TLP-веткой (TLP позже до-wired `Power.cycle`/`Power.refresh` idx 8 поверх — конфликта нет).
- **Статус:** код готов, парс-валидно, qs чист, механизм inhibit проверен. 🔴 НЕ запущено живьём (Арс ждёт niri-рестарт) · 🔴 НЕ закоммичено (Арс закоммитит сам; рекомендация — отдельная ветка `swayidle` от `tlp-power-cc`, не мешать с TLP, memory про feature-ветки). End-to-end (dim@5/lock@10/suspend@30/lid/CC-toggle живьём) НЕ верифицировано — test plan в спеке §«Test plan».

## 🔒 Session 2026-05-20 — Quickshell screen locker (swaylock снесён)

**Решение Арса:** swaylock как отдельный бинарь — отказаться. Локер живёт **внутри quickshell-шелла** (один Qt-процесс, общая Theme/Field), визуально продолжает greeter. Ветка `quickshell-lock` (13 коммитов от `try-terminess-bar`), fast-forward-смержена в `laniakea`.

- **Спека/план:** `docs/superpowers/specs/2026-05-20-quickshell-lock-design.md` + `docs/superpowers/plans/2026-05-20-quickshell-lock.md` (docs/ в .gitignore — локально).
- **Архитектура:** `LockScreen.qml` (Scope-root) = `WlSessionLock` (ext-session-lock-v1) с одним `WlSessionLockSurface` на экран + `PamContext{config:"login"}` + `IpcHandler{target:"lock"}`. `LockBox.qml` = кремовый прямоугольник 360×180 (тот же `Theme.boxFill`/Field/hostname-strip что у greeter'а). `LockClock.qml` = `SystemClock precision:Minutes` + HH:MM @160px + дата @24px. `Field.qml` скопирован один-в-один из `quickshell-greeter/` (тот же файл, но greeter-юзер не читает `/home/aru` — память `project-dotfiles-symlink-structure`).
- **Три стадии (`awake`, `revealed`)** — 🔄 ОБНОВЛЕНО 2026-05-21: лок теперь **clock-first**, как greeter (раньше стартовал asleep с чёрным flash'ем):
  1. **awake** (дефолт на лок) — `awake=true`, `revealed=false`. Сразу виден BigClock над dim-обоей, без чёрного flash'а. Встроенный `idleTimer{interval:600000, repeat:false}` гасит в asleep после 10 мин без key/click (экономия питания у lock-юзера, как у greeter'а). `wake()`/`reveal()` рестартят таймер, `dropLock()` его стопит.
  2. **revealed** — `boxSlot.height` 0→180 + `opacity` 0→1 (280/240ms OutCubic), `Column.spacing` 0→60. Column `anchors.centerIn:parent` пересчитывает центр — растущий слот "толкает" часы вверх. Печатный keystroke на reveal'е → `box.injectChar(text)` (заметка: `Field` — Item-обёртка, `cursorPosition` через `.input.cursorPosition`).
  3. **asleep** — `awake=false`. Чёрный Rectangle поверх всего, курсор `Qt.BlankCursor`. Достигается ТОЛЬКО по `idleTimer` (10 мин). Первый key/click только wake'ит — НЕ revealed, НЕ inject'ит.
- **Триггеры** (все три → один IPC):
  - `qs ipc call lock lock` — ручной + niri бинд `Super+Alt+L`.
  - swayidle `timeout 600` / `before-sleep` / `lock` хуки — три места переписаны.
  - `loginctl lock-session` — logind broadcast'ит, swayidle ловит на `lock` и зовёт IPC.
- **PAM:** `pam.active = true` стартует разговор; `onPamMessage` отвечает буфером `pendingPassword`; `onCompleted` Success → `dropLock()`, Fail → `clearCounter++` + status "auth failed — N" + `pam.active=false` (нельзя re-arm в том же тике — auto-respond'нёт пустым и зациклит). Манипуляция: `loginctl unlock-session` после `sessionLock.locked=false` синкает logind-state.
- **Greeter зеркалит state-machine.** `Greeter.qml` обёрнут в тот же `awake`/`revealed`, добавлен `BigClock.qml` (дубль `LockClock` под greeter-юзера). Отличие: greeter стартует **уже awake** (Арс: «на свежем pc — клок виден сразу»), но встроенный QML `Timer{interval:600000}` гасит в asleep на 10 мин неактивности (у greeter-юзера нет swayidle). `LoginBox` потерял внутренний `appearAnim` — теперь его раскрывает родительский слот. `LoginBox.injectChar(c)`/`focusInitial()` выбирают user-vs-pass-поле по `rememberedUser` (из `/var/cache/quickshell-greeter/last-user`).
- 🔴 **`qmldir` auto-generated** — новые QML-файлы НЕ подхватываются live-reload'ом до явного touch шелла. Симптом: `qs ipc show` не видит `target lock`. Лечится `touch shell.qml` (форсит перегенерацию). См. лог `qs log -r '*=true' | grep qmldir.*contains`.
- 🔴 **DPMS-off из лока — отложено.** Asleep = только чёрный Rectangle + скрытый курсор, экран физически НЕ выключается. Арс выбрал «не трогать DPMS» — реальный power-off делает swayidle на отдельной 10-мин таймауте.
- **Удалено:** `~/dotfiles/swaylock/` (stow-пакет целиком) + `~/.config/swaylock` (dangling symlink). Бинарь `/usr/bin/swaylock` оставлен — pacman-dep не дёргали (на случай ручного fallback'а).
- **Верифицировано вживую:** `qs ipc call lock lock` → asleep → wake → reveal → правильный пароль → unlock. Неправильный пароль → "auth failed — N" + clear. Greeter parse-clean через `timeout 3 qs -p /home/aru/dotfiles/quickshell-greeter/.config/quickshell-greeter/shell.qml` (greeter под greetd-юзером — live-verify только на следующем логине). НЕ верифицировано: реальные suspend/resume + 10-мин idle + multi-monitor.
- **Памяти, накопленные:** lock-screen Field-обёртка требует `.input.cursorPosition`; qmldir-stale при добавлении новых QML; greeter QML-Timer как замена swayidle под greeter-юзером.

## 🔋 Session 2026-05-19 — TLP charge-thresholds + CC EPP power-profile cycler

**Решение Арса:** настроить TLP (батарея 01AV471: 64 цикла, уже 90.3% capacity — float-charge на 100% старит), потом из CC переключать power-режимы. Ветка **`tlp-power-cc`** (5 коммитов, base `a49cbb9 "stable 1"`). 🔴 **НЕ смержено в `laniakea`** — Арс ревьюит сам; мерж = `git branch -f laniakea tlp-power-cc` (чистый fast-forward).

- **Спека/план:** `docs/superpowers/specs/2026-05-19-tlp-power-profile-cc-design.md` + `docs/superpowers/plans/2026-05-19-tlp-power-profile-cc.md` (docs/ в .gitignore — локально; в них «row 7» **устарело**, фактически row 8 после Auto-suspend re-index).
- 🔴 **X280 НЕ выставляет `/sys/firmware/acpi/platform_profile`** (пусто) — осмысленный power-knob тут **EPP** (`energy_performance_preference`, intel_pstate active/powersave), НЕ platform_profile. `power-profiles-daemon` НЕ установлен (конфликта нет).
- **TLP-пакет `~/dotfiles/tlp/`** — install.sh-пакет (НЕ stow), root-owned `/etc/tlp.d/`. `etc/tlp.d/00-aru.conf` = только 2 строки (`START_CHARGE_THRESH_BAT0=85` / `STOP_CHARGE_THRESH_BAT0=90`); drop-in грузится ПОСЛЕ `/etc/tlp.conf`, override-only, не сольётся с pacnew. `install.sh` (sudo): `pacman -S --needed tlp tlp-rdw smartmontools` (без `--noconfirm` — как остальные install.sh, не молча) → `install -m644` → `systemctl enable --now tlp.service` → `tlp start` (🔴 `enable --now` no-op на already-running → `tlp start` обязателен чтоб перечитать drop-in на re-run). Установлено+верифицировано: `/sys` = 85/90, `tlp-stat -b` подтверждает. smartmontools уже стоял.
- **EPP цикл — 4 режима.** `Power.qml` (`pragma Singleton`, как Brightness/Radio): `mode:int` 0..3 ↔ `eppValues=[performance, balance_performance, balance_power, power]` ↔ `labels=[Performance, Balanced (perf), Balanced (save), Power Save]`. `cycle(dir)` = `mode=(mode+dir+4)%4` **мгновенно** (лейбл флипает сразу) + `applyTimer.restart()`. `refresh()` = `cat /sys/.../cpu0/.../energy_performance_preference`, маппит; unknown/`default`→idx 1.
- 🔴 **Debounce 1500ms** (`applyTimer`, `repeat:false`): реальная запись в `/sys` отложена — мэшинг `L L L` Performance→Power Save = **один** `pkexec`, не три. На `setProc.onExited` ≠0 → `refresh()` ресинк лейбла с `/sys` (ряд не врёт). Live-only: TLP перезатрёт EPP на plug/unplug своим AC/BAT-дефолтом; `refresh()` на каждом открытии CC = лейбл честный. Без записи в tlp.conf.
- **Привилегии — зеркало `bluetooth-toggle.rules`.** `~/.config/quickshell/set-epp` (версионируется) → `sudo install -m0755 /usr/local/bin/set-epp`: POSIX-sh, whitelist токена (`case`), пишет во **все** `cpu*/cpufreq/energy_performance_preference` (intel_pstate не propagate'ит per-cpu запись). `~/.config/quickshell/epp-toggle.rules` → `sudo install -m0644 /etc/polkit-1/rules.d/49-epp-toggle.rules`: scoped (action `org.freedesktop.policykit.exec` + program `/usr/local/bin/set-epp` + user `aru`) → `pkexec` БЕЗ пароля. Оба установлены+верифицированы (pkexec без промпта, `/sys` флипает).
- **CC-проводка — row 8** (после Арсова Auto-suspend re-index): `PowerRow.qml` (модель `CcStatusRow`: «Power» слева + `Power.labels[Power.mode]` справа accentText, мышь-клик `cycle(1)`). `ControlCenter.qml`: `dispatchHL` case 8 → `Power.cycle(dir)`, `handleEnter` case 8 → `Power.cycle(1)`, `refresh()` += `Power.refresh()`.
- 🔴 **`ControlCenter.qml` НЕ на ветке `tlp-power-cc`** — правка row-8 лежит **uncommitted в working tree**, переплетена с Арсовой Auto-suspend-работой (тот же файл). Ветка = только новые файлы (`tlp/`, `set-epp`, `epp-toggle.rules`, `Power.qml`, `PowerRow.qml`). CC-проводку Арс коммитит сам вместе с Auto-suspend. См. memory `feedback-no-commits-no-branch-changes`.
- **Статус:** ✅ end-to-end верифицировано Арсом живьём («works, all perfect»): мгновенный флип лейбла, 1.5с debounced одна запись, без пароля, reopen в синке. spec+quality review каждого таска + холистик-ревью ветки пройдены.

## ⌨️ Session 2026-05-19 — keyd: CapsLock = nvim leader

**Решение Арса:** CapsLock бесполезен для регистра → **отключить toggle регистра и сделать его nvim `<leader>`**. Реальный CapsLock остаётся на **Shift+CapsLock** (Fn+CapsLock **невозможен** — на ноуте Fn обрабатывается прошивкой клавиатуры, до ОС не доходит; ни keyd/xkb/niri его не видят).

- **Механизм — keyd 2.6.0** (extra, был уже установлен; сервис был disabled → `enable --now`). Новый пакет `~/dotfiles/keyd/`: `etc/keyd/default.conf` + `install.sh` (sudo). **НЕ симлинкается** — `/etc/keyd/default.conf` root-owned вне `$HOME`, точно как `quickshell-greeter` (install.sh = source of truth: бэкап `.bak` один раз, copy, `systemctl enable --now keyd && restart`).
  - Конфиг: `[main] capslock = f19` · `[shift] capslock = capslock`.
- **nvim:** `vim.keymap.set({'n','x','o'}, '<F19>', '<Leader>', {remap=true})` в init.lua. Leader = дефолтный `\`. which-key показывает меню по одиночному CapsLock. Все существующие `<leader>…` бинды работают через CapsLock.

### 🔴 keyd → keysym: F19, НЕ F13 (verified `xkbcli compile-keymap`, не повторять цикл)

keyd шлёт **сырой Linux keycode**; keysym назначает уже **xkb**. В дефолтном `us` keymap keycodes F13–F24 забинжены на **vendor `XF86*` keysyms, которые терминалы молча ДРОПАЮТ**: `KEY_F13→XF86Tools`, F14-F18/F20-F24 → `XF86Launch*`/`XF86TouchpadToggle`/… **`KEY_F19` — ЕДИНСТВЕННЫЙ keycode с чистым `F19` keysym** (`key <FK13> {[ XF86Tools ]}` vs `key <FK19> {[ F19 ]}`) → только он доходит kitty→tmux→nvim. Симптом при F13: keyd работает (Shift+Caps ок), но nvim **ничего** не получает — `<leader>` не срабатывает (выглядит как «pattern not found»). Память-кандидат — но уже зафиксировано здесь + в комментах `keyd/etc/keyd/default.conf` и init.lua.

### 🔴 Lone CapsLock всё ещё шлёт F19 (Арс осознанно оставил)

Одиночный тап CapsLock = F19 уходит **глобально**, во все приложения, не только nvim. Арс выбрал это оставить (F19 без дефолтных биндов в др. приложениях → безвредно). Вариант hold-modifier (keyd `overload`, тап = ничего) **отклонён** — сломал бы sequence-leader (`<leader>ff`, `<leader>n` требуют тап-потом-клавиши, не hold).

### Terminal (toggleterm) — caps+t / caps+q

- **CapsLock+t** = toggle терминала (show/hide, shell жив). **CapsLock+q** = close (kill shell; след. caps+t = свежий shell).
- Биндинги: n-mode `<leader>t`/`<leader>q`; t-mode `<F19>t`/`<F19>q` (внутри терминала `<leader>` не забинжен, и шэдоуить shell `\` нельзя → матчим F19 напрямую, симметрично).
- 🔴 **Префикс-делей урок:** сперва было `<leader>tt` для close → `<leader>t` висел ~`timeoutlen` (t стал prefix). caps+**c** тоже отклонён: `<leader>ca` = LSP code-action → тот же делей + тормозит code-action. Итог: оба ключа **leaf** (`t`, `q`), ноль задержки.
- toggleterm spec: `opts` → `config`-функция (setup + keymaps + `kill()` = `require('toggleterm.terminal').get_all(true)` → `:shutdown()`); встроенный `open_mapping` убран.

## 🔐 Session 2026-05-18 — login: quickshell-greeter заменил regreet

**Решение Арса:** regreet («works but looks awful») → **кастомный quickshell-greeter** под Sky Paper. Тот же стек что бар (Theme SSOT, Unifont crisp-рецепт, FloatingWindow).

- Исходник: stow-пакет `~/dotfiles/quickshell-greeter/.config/quickshell-greeter/` (`shell.qml`/`Greeter.qml`/`LoginBox.qml`/`Field.qml`/`Theme.qml`). **НЕ симлинкается** — greeter-юзер не может пройти `/home/aru` (mode 700), ставится в `/etc/quickshell-greeter/` скриптом `~/dotfiles/quickshell-greeter/install.sh` (sudo). Greetd-конфиг версионируется в `~/dotfiles/quickshell-greeter/etc/greetd/config.toml`.
- Вид: clouds.png (dim 0.50) + кремовый прямоугольник 360×180 (kitty-bg @0.7) по центру; `> user` (blue) / `> pass` (black, `*`-mask); хедер `laniakea`; pop-in scale+fade 200ms; remember-user в `/var/cache/quickshell-greeter/last-user` (FileView, dir = `greeter:greeter`).
- Логин-флоу: PAM-разговор управляется из `onAuthMessage` (буферим пароль, авто-`respond`), НЕ по клавише на шаг. Итог: `[user] Enter [pass] Enter` (с remember — только `[pass] Enter`).

### 🔴 Грабли greetd+cage+Qt (НЕ повторять цикл — всё проверено логами)

1. **`QT_QPA_PLATFORM=wayland` ОБЯЗАТЕЛЕН** в greetd-команде. Минимальное greetd-окружение → Qt берёт xcb-плагин → нет X → **FATAL до загрузки QML** (чёрный экран + курсор). Лог: `Could not load the Qt platform plugin "xcb"`.
2. **cage НЕ умеет wlr-layer-shell.** Greeter = **FloatingWindow (xdg-toplevel), НЕ PanelWindow.** Layer-сюрфейс не мапится → blank+cursor. Лог: `Failed to initialize layershell integration`. (regreet работал т.к. GTK = обычный toplevel.)
3. **`QT_WAYLAND_DISABLE_WINDOWDECORATION=1`** — иначе Qt рисует свой CSD-титлбар «quickshell» + кнопки (видно и в niri-превью, и в cage).
4. **НЕ оборачивать сессию в `sh -c`.** greetd exec'ает команду напрямую; `Greetd.launch(["sh","-c","exec niri-session …"])` → сессия мгновенно выходит → **bounce-loop назад в greeter** (журнал: `session opened … session closed` через ~1s, цикл). Только `Greetd.launch(["niri-session"])`.
5. **Логи greeter'а:** greetd НЕ форвардит stdout qs в журнал, runtime-dir greeter-юзера недоступен. Дебаг — временно редирект qs в `/var/cache/quickshell-greeter/qs.log` (greeter-writable). Превью без cage: `qs -p /etc/quickshell-greeter` из niri (Greetd.available=false → Esc выходит).
6. **Переход greeter→niri мигает** (VT/DRM handoff: cage отпускает GPU → текстовая консоль ~доли сек → niri). Логи уже тихие (`loglevel=3 quiet`, GRUB). Принято как есть — true-seamless требует plymouth/persistent-compositor (отложено).

## ⚡ Session 2026-05-18 — quickshell заменил waybar (главное)

**Решение Арса:** waybar → **quickshell целиком** (energy: один Qt-процесс; footprint принят по факту). waybar-конфиг НЕ тронут, откат = одна строка в niri config.

- quickshell 0.3.0 (extra). **На rolling Arch пакет собран под старый Qt — пересобран под текущий Qt 6.11.1** через `makepkg -si` в `~/build/quickshell` (клон Arch packaging repo). При будущих Qt-бампах qs может снова «likely crashes» → пересобрать так же.
- Конфиг: новый stow-пакет `~/dotfiles/quickshell/.config/quickshell/`, **directory symlink** `~/.config/quickshell` → туда.
- Архитектура (мелкие focused файлы):
  - `Theme.qml` — **Singleton, единый Sky Paper SSOT** (все hex + шрифт + размеры). Правишь тут — перетемливается всё.
  - `NiriIpc.qml` — **Singleton, один `niri msg --json event-stream`** как триггер → перечитывает снапшоты `workspaces`/`keyboard-layouts`. Язык/воркспейсы **мгновенно** — старый Python-лаг (old issue #12) убит как класс.
  - `Bar.qml` — PanelWindow (layer-shell top, height 22, barBg `#BFE4DED0` = 0.75 как старый waybar). Layout: `[ws №] ··· [clock] ··· [lang] [λ]`.
  - `Workspaces.qml` — **1:1 с waybar #workspaces CSS**: кнопка во всю высоту бара, 6px h-padding, square; active `#FFFFFF`, urgent `#1F1812@0.9`/`#F0EBE0`, empty `#C5BFB5`, else `#7A716A`.
  - `Clock.qml` — `SystemClock precision: Minutes` (без посекундных wakeup), `dd.MM HH:mm`, pixel-snapped позиция.
  - `Language.qml` — `NiriIpc.layoutShort`, клик → `niri msg action switch-layout next`.
  - `ControlCenter.qml` — **шторка: shell + nav + key-dispatch. Бэкенды и ряды разнесены по файлам — см. секцию ниже**.
- **Иконка control-center в баре = `λ`** (Unifont).

### 🔴 Шрифт в quickshell — РАЗОБРАНО (важно, не повторять цикл)

- **Бар использует `Unifont` @16** (в `Theme.qml`). Unifont = true bitmap-strike → Qt Quick рендерит **чётко/резко** (Арс подтвердил). ЭТО ФИНАЛ для бара.
- `Terminess Nerd Font Mono` = scalable outline → Qt Quick его **антиалиасит, мыльный**, не 1:1 с waybar/Pango. Это **движок Qt Quick vs Pango, не «не тот шрифт/размер»**. Crisp-рецепт уже стоит везде: `renderType: Text.NativeRendering` + `font.hintingPreference: Font.PreferFullHinting` + integer pixel-snap + px-size.
- **Family-name trap:** резолвится только точное `Terminess Nerd Font Mono`. `Terminess Font Mono` (без «Nerd») → fallback **Noto Sans**. Всегда `fc-match` перед доверием.
- Подробности: память `reference-quickshell-bitmap-font-blur`.

### ✅ ControlCenter — keyboard-driven, разнесён по файлам (2026-05-18 phase A+B+рефактор; 2026-05-19 wifi-fix+power-toggle+анимация)

**Состояние:** полностью клавиатурный (hjkl), бэкенды → синглтоны, каждый тип ряда → свой компонент-файл. `ControlCenter.qml` ужат ~680 → **284 строки**.

- **Открытие/закрытие:** `PopupWindow{grabFocus:true}`, anchored под `λ`, правый offset = **9px** (= niri `gaps 8 + border 1`, память `project-bar-niri-edge-align`). Варн `not an xdg_popup` остаётся, работает. Анимации **210ms** (open OutCubic / close InCubic; `panelSlide.y -10→0` + opacity; `onFinished`→`visible=false`). 🔴 Имена `openCc/closeCc/toggleCc` — НЕ `show/hide/toggle` (шэдоуят QWindow). Дебаунс 250ms. Esc/Q закрывают.
- **🔴 Клавиатура в попап:** `Bar.qml` обязан иметь `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` — иначе xdg-popup grab не получает клавиатуру и hjkl/Esc/q не доходят. Тоггл: клик по `λ` + `Mod+Space` (niri-бинд `repeat=false`, иначе мигание) → `qs ipc call controlcenter toggle`.
- **Грамматика рядов:** J/K — между рядами (wrap, бесконечный скролл). H/L — toggle-флип / slider ±5% / **открыть список** (закрытый) / **активировать выделенный пункт** (открытый список — НЕ скролл, скролл это J/K). Enter — то же что H/L в списке + Volume mute / footer-action. Esc/Q — закрыть открытый список, иначе закрыть шторку.
- **Порядок (sliders → toggles → lists → footer):** 0 Brightness · 1 Volume · 2 Airplane · 3 Warm · 4 Auto-suspend · **5 Quiet** · 6 BT · 7 Wifi · 8 Output · 9 Power · 10/11 Power footer (Lock·Logout·Sleep / Hibernate·Reboot·Shutdown). `rowCount=12`. Quiet (mako DND) добавлен 2026-05-20 — сдвинул BT/Wifi/Output/Power/Footer на +1; все idx-чеки в `dispatchHL`/`handleEnter`/`listLen`/`openList`/`commitList`/`armOrFire`/Connections re-index'нуты.
- **Tier 1 — бэкенд-синглтоны** (`pragma Singleton`, авто-qmldir):
  - `Brightness.qml` — brightnessctl get/set (0–100).
  - `NightLight.qml` — wlsunset warm-toggle. 🔴 wlsunset требует **high > low** temp (равные → тихая ошибка в stderr): `-T 5500 -t 5499`. Долгоживущий демон → **отдельные start/stop Process + `setsid -f`** (один переиспользуемый Process залипает в `running` навсегда, молча игнорит следующий `.running=true`). Память `reference-wlsunset-quirks`.
  - `Radio.qml` — airplane (`rfkill block/unblock all`) + bt-статус (`rfkill bluetooth`).
  - `WifiCtl.qml` — nmcli scan/list/saved/connect/**disconnect** (`con down id`) + activeSsid + **`enabled`** (`nmcli radio wifi on/off` через `setEnabled`). Пароль через **env `PASS`** (не argv → не в `/proc/*/cmdline`). 🔴 nmcli `-t` экранирует `:` как `\:`; **split нельзя через regex-lookbehind** `(?<!\\):` — у Qt V4 НЕТ lookbehind, он молча НЕ матчит (не кидает SyntaxError) → split вернул всю строку, networks=[] навсегда («scanning…» вечно — это и был баг). Чинится: mask `\:`→`\x01`, split по `:`, restore. Память `reference-qt-v4-no-regex-lookbehind`.
  - `BtCtl.qml` — bluetoothctl scan/devices/paired/connected/connect/pair/disconnect + activeDevice + `powered` + `available`. **Зеркало WifiCtl, но с двумя расхождениями по природе BT:** (1) **BT НЕ всегда-running** (батарея) — в отличие от nmcli/NM. Toggle on-demand: ON = `systemctl start bluetooth && sleep 1 && bluetoothctl power on`, OFF = `bluetoothctl power off; systemctl stop bluetooth` (через `setPowered`). 🔴 Старт system-юнита из непривилегированного шелла требует **одноразового polkit-правила** — версионируется `~/.config/quickshell/bluetooth-toggle.rules`, ставится `sudo install -m644 … /etc/polkit-1/rules.d/49-bluetooth-toggle.rules` (scoped: только `bluetooth.service`, только юзер `aru`; polkit подхватывает rules.d live). БЕЗ правила toggle молча no-op'ит (polkit denies start). (2) **bluetoothctl ВИСИТ вечно (no fast-fail) когда bluez down** — не как nmcli. Фикс: один быстрый `probe` (`timeout 2 bluetoothctl show`) гейтит всё — `available = text.indexOf("Powered:")>=0`; если down → degrade в "off" за **~2с** вместо ~14с «scanning…» churn (каждый probe иначе блокировал бы свой timeout + scanProc их re-fire'ит). bluez up → probe мгновенный D-Bus, как nmcli. Память `reference-bluetoothctl-hangs-no-daemon`.
  - `PowerActions.qml` — `run(idx)`: suspend / `niri msg action quit` / reboot.
  - `SuspendInhibit.qml` — `enabled` (true=suspend разрешён, session-scoped). `toggle()` → Quickshell `Process{running:!enabled}` держит `systemd-inhibit --mode=block --what=sleep` пока OFF; SIGTERM при ON/destruction снимает. Ряд idx 4 «Auto-suspend». 🔴 SIGKILL qs = сирота-inhibit держит lock. См. секцию «🌙 Session 2026-05-19 — swayidle».
  - `Notifications.qml` — `dnd:bool`. `toggle()` → `makoctl mode -t do-not-disturb` (оптимистично флипает `dnd`, `refresh()` на открытии CC корректирует). `refresh()` grep'ает `makoctl mode` на наличие `do-not-disturb`. Ряд idx 5 «Quiet». Без периодики — состояние меняется только нашим toggle'ом + redrаw на CC-open.
  - `Power.qml` — EPP-цикл, ряд idx 9. `mode:int` 0..3 ↔ `eppValues`/`labels` (Performance/Balanced perf/Balanced save/Power Save). `cycle(dir)` флипает `mode` мгновенно + 🔴 **1500ms `applyTimer` debounce** → один `pkexec /usr/local/bin/set-epp <token>` (зеркало `bluetooth-toggle.rules`-привилегий: `epp-toggle.rules` polkit → без пароля). `refresh()` на открытии CC читает `/sys/.../cpu0/...energy_performance_preference`. Live-only (TLP перезатрёт на plug/unplug). См. секцию «🔋 Session 2026-05-19 — TLP + CC EPP».
- **Tier 2 — компоненты рядов** (инъекция `property var cc` для общего nav-state):
  - `CcText.qml` — общий crisp-стиль (был inline `component CcText`).
  - `CcToggleRow` (Airplane/Warm) — пиксель-свитч 22×12 + бегунок 8×8, **solid fills** (borderDim тонет в cream/blue).
  - `CcSliderRow` (Brightness/Volume) — сигнал `seek(frac)`, value 0–100, `suffix` для «(muted)».
  - `CcStatusRow` — label + правый статус-текст. Сейчас **никем не используется** (Power → свой `PowerRow`, BT → `BtRow`); оставлен как generic-примитив.
  - `PowerRow` (Power, ряд 8) — модель `CcStatusRow`: «Power» слева + `Power.labels[Power.mode]` справа в accentText, focus-highlight, мышь-клик → `Power.cycle(1)`. H/L/Enter цикл — в `ControlCenter.qml` (case 8).
  - `CcFooterRow` — Sleep/Logout/Reboot, `footerCol` H/L.
  - `WifiRow` — collapsed SSID / expanded ListView (6 видимых). **Ряд 0 списка = power-toggle** (label «Wi-Fi» + пиксель-свитч как у `CcToggleRow`, контраст-aware на выделении) → `setEnabled`, флипает на месте, список НЕ закрывает. Сети = idx 1..N (pixel signal-bars + pixel-padlock); активная сеть при активации → `disconnect`. Inline password `TextInput` (echo Password, auto-focus). **Анимация раскрытия:** root `clip:true` + `Behavior on height` 170ms OutCubic; ListView держится смонтированным пока `height>36` → clip плавно открывает/прячет вместо «pop». Открытие списка также по H/L (не только Enter).
  - `BtRow` — collapsed connected-device / expanded ListView, **зеркало `WifiRow`**: ряд 0 списка = power-toggle (label «Bluetooth» + тот же пиксель-свитч), устройства idx 1..N, активация подключённого → `disconnect`, неспаренного → pair+trust+connect, та же `clip:true` + `Behavior on height` 170ms анимация, H/L открыть/активировать. **Расхождения (BT не имеет аналога — честно, не молча):** нет password-поля (BT-спаривание без печатного секрета); вместо signal-bars — **connection-pip** (bluetoothctl не даёт сигнал); вместо padlock — **«unpaired» полый квадрат**.
  - `OutputRow` — Pipewire sink-list (мышь).
- **🔴 Глифы отвергнуты (не повторять цикл):** Unifont = bitmap, декоративные Unicode (`✷≋☀☾♪▶⚡`) рендерятся разнокалиберно / падают в fallback-шрифт. Только пиксель-примитивы (Rectangle), как signal-bars. Юзер: «ugly ass fuck and not the same size».
- **Валидация:** live-reload (память `reference-quickshell-stale-cache-errors`) + standalone-харнес `qs -p /tmp/...` который гоняет реальный синглтон и `console.log`-ает (лог рантайма идёт в /dev/null, `qs log` читает бинарный `.qslog`; pass/fail кодируется в `Qt.exit`). Wifi-flow юзером подтверждён («works»): scan/list/h-l-open/power-toggle. **BT:** QML грузится чисто (isolated-reload delta, zero warnings), fail-fast probe замерен эмпирически (~2с degrade при bluez down). НЕ верифицировано end-to-end: живой on→scan→pair→connect (требует установленного polkit-правила + реального устройства + чтоб bluez стартовал). Остальные ряды (Output/Power/footer) end-to-end юзером ещё не гоняны.

### 🗺️ ControlCenter — future map

1. **BT (ряд 4)** — ✅ СДЕЛАНО 2026-05-19: `BtCtl`+`BtRow`, device-picker зеркало Wifi (paired/connected/connect/pair/disconnect, list-mode `openList/scrollList/commitList`), on-demand bluez + fail-fast probe. ОСТАЛОСЬ: индикатор «pairing…/connecting…» после connect; авто-rescan по таймеру пока список открыт (как у Wifi item 4). 🔴 Перед использованием — поставить polkit-правило (см. `BtCtl.qml` выше), иначе toggle не стартует bluez.
2. **Output (ряд 6)** — добавить keyboard list-mode (сейчас только мышь). 🔴 `Pipewire.nodes` не итерируется как JS-массив — нужен ObjectModel-обход для `listLen()/commitList()`.
3. **Power (ряд 8)** — ✅ СДЕЛАНО 2026-05-19: `Power.qml`+`PowerRow.qml`, 4-режимный EPP-цикл (debounced pkexec, polkit). End-to-end верифицировано. На ветке `tlp-power-cc` (не смержено). 🔴 НЕ list-ряд (отказались — 4 пункта не стоят list-mode); 🔴 НЕ platform_profile (X280 не выставляет) и НЕ `powerprofilesctl` (ppd не стоит) — именно **EPP** через `set-epp`.
4. **Wifi** — ОСТАЛОСЬ: авто-rescan по таймеру пока список открыт; индикатор «connecting…» после connect/disconnect; disconnect по имени интерфейса как fallback к `con down id`. (power-toggle / disconnect / h-l-open / анимация — СДЕЛАНО 2026-05-19.)
5. **Дедуп** — бар-овые `Wifi.qml`/`Battery.qml` могут переиспользовать `WifiCtl` + новый `BatteryCtl` синглтон вместо своих Process.
6. **Tier 3 (опц.)** — generic `CcListRow` если BT/Output/Power будут одинаковы; пока разнесены намеренно (риск был в этом).

## Installed since prior snapshot

- **swaybg** — wallpaper provider, autostart из niri
- **greetd + cage + quickshell-greeter** — login manager stack (greetd-regreet и xorg-xwayland удалены)
- **keyd 2.6.0** (extra) — CapsLock-ремап (был установлен, сервис включён 2026-05-19)
- **Unifont, cozette-otb, terminus-font-td1-ttf, otf-departure-mono** — пробовали в font-итерациях
- **jp2a, imagemagick** — для ASCII art конвертации (план)

---

## Rice — direction & state

**Philosophy:** minimalism + angelic Ghibli vibe. Painterly soft. High contrast только в основном тексте (vim).

**Current palette: Sky Paper** — warm cream + dual sky accent. Inspired by `~/Pictures/wallpapers/clouds.png` (Ghibli sky illustration).

| role | hex | назначение |
|---|---|---|
| bg | `#F0EBE0` | warm cream, cloud highlight |
| bg-alt | `#E4DED0` | bars / panels |
| border-dim | `#C5BFB5` | inactive borders |
| muted | `#7A716A` | комменты, inactive |
| fg | `#1F1812` | основной текст (15:1 contrast) |
| accent-soft | `#A8C0D5` | UI fills (borders, button bg, current ws) |
| accent-text | `#4A6F8E` | text accents (keywords, links, current window) |

**Полная карта:** `~/dotfiles/PALETTE.md`.

### Palette iteration history (NE ITERIROVAT' BEZ NAPRAVLENIYA)

1. Kanagawa Lotus — отвергнут «тусклое»
2. Vague — отвергнут «не чёрно-белое»
3. Mono-dark — applied
4. Mono-dark + wine red `#a04050` — отвергнут «всё не так»
5. Cool Mono (purple/teal на dark) — отвергнут
6. Cool Paper (light mono cool) — отвергнут «office clean»
7. **Sky Paper (current)** — applied, под clouds.png

`palette-lotus.md` — архив kanagawa.

### Font — RESOLVED 2026-05-17

**Финальный стек:** `Terminess Nerd Font Mono` (= Nerd-Font-patched Terminus TTF) везде. Plus Unifont как synthesized italic в kitty.

- **kitty:** `font_family Terminess Nerd Font Mono` @ 12.0pt. `italic_font Unifont` + `bold_italic_font Unifont` — kitty синтезирует наклон/жирность из Regular (Unifont не имеет italic style). `symbol_map U+3000-U+9FFF,U+F900-U+FAFF Unifont` для CJK. `modify_font font_size Unifont +4` чтобы CJK-глифы не выглядели sliced.
- **waybar:** `font-family: "Terminess Nerd Font Mono"; font-size: 12pt;` в `* {}`. Сильно: `font-style: normal` тоже там — Pango пытался синтезировать italic в tooltips.
- **regreet:** `Terminess Nerd Font Mono 11` в `regreet.toml`, и `font-family: "Terminess Nerd Font Mono"` в `style.css`.

**Почему не bitmap (.otb/.pcf):** Кitty фильтрует non-scalable шрифты через fontconfig (`scalable=True` required). Cozette OTB (`scalable=False, outline=False`) НЕ работает как `font_family`, только через `symbol_map`. Это hard limitation kitty. Поэтому остановились на Nerd-Font-patched Terminus (TTF, scalable=True, monospace=100).

**Fontconfig override:** `~/.config/fontconfig/conf.d/10-terminus-alias.conf` aliases `Terminus` → `Terminus (TTF)`. Сейчас не нужен (мы используем "Terminess Nerd Font Mono" напрямую) но оставлен — другие приложения могут спрашивать "Terminus".

**Terminess AA-off per-size** (🔄 2026-05-21): `~/.config/fontconfig/conf.d/20-terminess-bitmap.conf` отключает AA+hinting для Terminess **только на нативных pixel-размерах** (12/14/16/18/20/22/24/28/32) — один `<match>` блок на размер (тесты внутри блока AND'ятся, OR размеров = отдельные блоки). На ЛЮБОМ другом размере AA-off рисует битые глифы (полу-нарисованные буквы, рваные края) — что и было в Obsidian с произвольными размерами + zoom. Поэтому не-нативные размеры держат системный дефолт (AA ON) → Terminess гладкий там, где не pixel-perfect.

**GTK3 CSS gotchas (узнано на горьком опыте):**
- `font-family` НЕ принимает fallback list с `!important` — `"X", monospace !important` → "Junk at end of value". Без `!important` норм, или одиночное family с `!important` норм.
- `<b>`, `<big>` Pango tags в tooltip-format = жирный. `<span weight='normal'>` принудительно отменяет.

---

## Stack — что настроено сейчас

| Component | Status | Notes |
|---|---|---|
| niri | done (visuals) | border 2px active=`#A8C0D5`, inactive=`transparent`, urgent=`#1F1812`. Focus-ring off. shadow ON warm `#1F181240` softness 24 offset y6. tab-indicator top place-within-column active=`#A8C0D5` inactive=`#C5BFB5`. insert-hint `#A8C0D580`. background-color `#F0EBE0`. geometry-corner-radius 8 + clip-to-geometry для всех окон. overview backdrop `#E4DED0` + workspace-shadow `#1F181233`. layer-rule walker shadow on + radius 14. hotkey-overlay hide-not-bound. Global window opacity 0.85. swaybg clouds.png. |
| swaybg | done | `~/Pictures/wallpapers/clouds.png`, mode=fill |
| kitty | done | Terminess Nerd Font Mono 12pt + Unifont для italic. Sky Paper палитра. symbol_map CJK→Unifont, `modify_font font_size Unifont +4`. Раньше был `cell_width` хак — снят. |
| tmux | done | Sky Paper statusline. status-left = session marker. status-right = git branch с ` ` glyph (`#(cd '#{pane_current_path}' 2>/dev/null && b=$(git symbolic-ref --short HEAD 2>/dev/null) && [ -n "$b" ] && echo " $b")`). Plugins: TPM, resurrect, continuum. |
| nvim | done | vague.nvim с Sky Paper override. Custom lualine theme `sky_paper`. fg=`#1F1812` (extreme contrast), keyword=`#4A6F8E` (deep sky). **Leader = CapsLock** (`<F19>`→`<Leader>` `\`, remap, n/x/o). toggleterm: `<leader>t` toggle / `<leader>q` kill, плюс t-mode `<F19>t`/`<F19>q`. |
| keyd | done | 2.6.0 (extra), сервис enabled. CapsLock→`f19`, Shift+CapsLock→реальный `capslock`. Конфиг `~/dotfiles/keyd/etc/keyd/default.conf` → `/etc/keyd/default.conf` через `keyd/install.sh` (sudo, root-owned, НЕ симлинк). 🔴 F19 (не F13) — см. секцию «⌨️ Session 2026-05-19». |
| ~~waybar~~ → **quickshell** | заменён 2026-05-18, waybar-пакет снесён 2026-05-21 | `waybar/` stow-пакет + `~/.config/waybar` симлинк + pacman-пакет удалены (qs-стек зрелый — бар+CC+лок+лаунчер). Откат больше не «одна строка». niri autostart: только `spawn-at-startup "qs"`. Полное описание quickshell — в секции «⚡ Session 2026-05-18» выше. Бар: Unifont@16, текст чёрный (Theme.fg). Воркспейсы = 1:1 со старым waybar (активный = белый бокс во всю высоту, берётся из `NiriIpc.activeWs`). **Язык: при смене раскладки за текстом мигает белый бокс** (SequentialAnimation, 280ms). Симметрия отступов 12px слева/справа. Иконка control-center = `λ`. |
| regreet | done | greetd + cage + regreet + xorg-xwayland. `/etc/greetd/config.toml` → `cage -s -- regreet`. Конфиг в `~/dotfiles/regreet/.config/regreet/`. CSS под Sky Paper. Запускается на VT1. Aрс отзыв: «works but looks awful» — потенциально шрифт + ассеты. |
| fish | partial | 4.7.1 установлен. Config: `set -U fish_greeting ""` + `alias vim='nvim'`. Niri autostart-в-fish УДАЛЁН после установки regreet (теперь regreet запускает niri через `/usr/share/wayland-sessions/niri.desktop`). `chsh` на fish — статус не верифицирован, возможно ещё bash. |
| launcher | done (2026-05-21) | **quickshell-native, заменил tofi.** `Launcher.qml` (PopupWindow-вью) + `AppLauncher.qml` (singleton-бэкенд: `DesktopEntries` + fuzzy + frecency + calc + run). Живёт в резидентном `qs` (Bar.qml декларирует `Launcher{}` рядом с CC) → нет cold-start, открывается как CC. Mod+D → `qs ipc call launcher toggle`. Глиф `Δ` (паре к `λ`) на баре по центру: по бинду часы fade-out (280ms), `Δ` едет влево, input разворачивается вправо на баре, результаты (макс 5) падают вниз отдельным боксом цвета `barBg` (читается как продолжение бара). Навигация: печать фильтрует, ↓/Tab ↑/Shift+Tab двигают, Enter запуск, Esc закрыть. 3 режима в одном поле: приложения (fuzzy+frecency); калькулятор (авто-детект чистой арифметики, Enter→`wl-copy`); `» run: <q>` фоллбэк (`sh -c`) когда нет совпадений. Frecency: `~/.local/state/quickshell/launcher-frecency.json` через `FileView` (freq×recency, bump на launch). Fuzzel/walker/anyrun/wofi отвергнуты — qs-native сразу. |
| power-menu | done (2026-05-20) | внутри quickshell control center — **скрываемая секция** (ряды 10 Lock·Logout·Sleep + 11 Hibernate·Reboot·Shutdown, 2px зазор). По умолчанию НЕ видна. Mod+Shift+E → `qs ipc call controlcenter togglePower` — анимирует секцию вниз (height+opacity, 200ms OutCubic) и фокус на Lock. Esc внутри секции — скрывает её обратно, фокус на ряд 0 (CC остаётся открытым). Esc на ряде 0 — закрывает CC. hjkl section-aware: {0..9} и {10,11} — два изолированных wrap-кольца, hjkl не пересекает границу. На рядах 10/11 H/L тоже wrap'ит {0..2} (не clamp). Каждая кнопка = arm-then-confirm: первый Enter взводит (пульсация 0.5с цикл, окно 5с), второй Enter — fire. Esc/move/timeout — disarm. Старый `~/dotfiles/niri/.config/niri/power-menu.sh` + tofi `power.config` удалены. logout = `niri msg action quit --skip-confirmation`. **lock = `loginctl lock-session`** (logind → swayidle → `qs ipc call lock lock` → Quickshell `LockScreen`). |
| mako | done (2026-05-20) | stow `mako/`, `~/.config/mako/config`. Top-left popups (360×90, Terminess 12, cream `#F0EBE0` @ 90%, 1px borderDim, square corners), aligned 1px right of niri window border (margin `8,9,8,8`). Two-line Pango: bold summary + muted body. `default-timeout=5000`, low=3000, critical=0. `[mode=do-not-disturb] invisible=1` — без этой секции DND-режим **не подавляет** попапы (mako рендерит как обычно). DND через CC ряд 5 «Quiet» → `makoctl mode -t do-not-disturb` через `Notifications` singleton. niri `spawn-at-startup "mako"`. 🔴 mako 1.11 отвергает `padding=6 12` (space) — нужны запятые `padding=6,12`; `max-icon-size=0` тоже rejected (redundant с `icons=0` — выкинуть). |
| eww | not configured | (Phase 5) |
| yazi | done (2026-05-22, Esc→leave 2026-05-24) | stow `yazi/`, Sky Paper theme + vendored icon table. `keymap.toml` = `<Esc>`→`leave` (зеркало `h`). `.stow-local-ignore` есть. Подробности ниже. |
| zathura | done (2026-05-24) | stow `zathura/`, Sky Paper `zathurarc`, mupdf-бэкэнд (PDF/ePub/XPS/CBZ). `install.sh` ставит pkg + `xdg-mime default` для тех же mime'ов (раньше PDF открывался в firefox). Подробности ниже. |
| obsidian | done (2026-05-24) | `obsidian/` (НЕ stow, install.sh-only — конфиг живёт per-vault, не XDG). Sky Paper CSS-сниппет + `.obsidian.vimrc` + `hotkeys.json` симлинкуются в `~/Documents/Obsidian/second_brain/`. Тема — Obsidian default (Minimal был испробован, отвергнут — без Style Settings прячет inactive-tab title целиком, CSS не достаёт). Подробности ниже. |
| firefox | not configured | |
| GTK theme | not configured | |
| swayidle + qs-lock | done (verified live, 2026-05-20) | swayidle: stow-пакет, 5м dim → 10м lock+screen-off → 30м suspend + before-sleep/lock хуки, все три зовут `qs ipc call lock lock`. **swaylock-пакет снесён** — лок делает Quickshell-локер (`LockScreen.qml` + `LockBox.qml` + `LockClock.qml` через `WlSessionLock` + `PamContext`). niri `spawn-at-startup "swayidle" "-w"` + `Super+Alt+L`. CC-ряд «Auto-suspend» (idx 4) блокирует 30м-suspend+lid через `systemd-inhibit`. См. «🔒 Session 2026-05-20 — Quickshell screen locker». |
| tlp | done (verified live) | install.sh-пакет `~/dotfiles/tlp/` (НЕ stow). drop-in `/etc/tlp.d/00-aru.conf` = только charge-thresholds 85/90 BAT0; `/etc/tlp.conf` не тронут; EPP-дефолты TLP-овские. Установлено+верифицировано (`/sys`=85/90). CC EPP-цикл (ряд 8) поверх — ветка `tlp-power-cc`, не смержена. См. «🔋 Session 2026-05-19 — TLP + CC EPP». |

---

## Stow packages

Актуальные на laniakea: kitty, niri, nvim, tmux, regreet, fish, **swayidle**, **yazi**, **zathura**. (`swaylock/` снесён 2026-05-20 — лок теперь часть quickshell-шелла; `tofi/` снесён 2026-05-21 — лаунчер теперь часть quickshell-шелла; `waybar/` снесён 2026-05-21 — бар теперь часть quickshell-шелла.)

🔴 **`.stow-local-ignore` convention** (введено 2026-05-24): любой stow-пакет, у которого на верхнем уровне лежит **не-config**-файл (`install.sh`, `CHEATSHEET.txt`, etc.), обязан иметь `.stow-local-ignore`. Stow-дефолт игнорит только `README.*` / `LICENSE.*` / `COPYING.*` — `install.sh` и `CHEATSHEET.txt` иначе утекают симлинками прямо в `$HOME` после `stow <pkg>`. Локальный ignore **заменяет** дефолтный (не extend) — поэтому в файле сначала репродуцируется полный stow-built-in список, потом добавляются локальные правила. Примеры готовых файлов: `yazi/.stow-local-ignore`, `zathura/.stow-local-ignore`.

**yazi** (2026-05-22, keymap.toml добавлен 2026-05-24, todo #17): stow `yazi/.config/yazi/` → directory symlink. `theme.toml` оверрайдит встроенный `theme-light` пресет (Sky Paper). Nerd-иконки ОСТАВЛЕНЫ, но таблица `[icon]` вендорится с вырезанными `fg` (`sed -E 's/, fg = "[^"]*"//g'` по `[icon]`→EOF апстрим-пресета) → глиф наследует цвет имени файла (нейтрализовано, не радуга). `sky-paper.tmTheme` = синтаксис превью кода под палитру nvim. `yazi.toml` = только `linemode = "size"`. **`keymap.toml`** (2026-05-24): один `prepend_keymap` в `[mgr]` — `<Esc>` мапится на `leave` (родительский dir, зеркало `h`). Trade-off: дефолтный Esc-clears-find/filter теряется — для clear-filter использовать `,` / `<Bspace>`. Всё остальное сток: `d`=trash, `D`=delete, превью всегда вкл. `install.sh` (sudo, НЕ stow): `ffmpegthumbnailer`+`poppler` для video/PDF-превью (картинки через kitty graphics и так). `CHEATSHEET.txt` = сток-бинды. `.stow-local-ignore` добавлен 2026-05-24 (см. секцию выше). 🔴 Скруглённые углы попапов захардкожены в Rust-бинаре (`BorderType::Rounded` в input/cmp/tasks/notify/confirm/pick) — НЕ чинятся конфигом, приняты как есть.

**zathura** (2026-05-24, todo #22): stow `zathura/.config/zathura/zathurarc` → directory symlink. Палитра Sky Paper (default-bg `#F0EBE0`, fg `#1F1812`, statusbar/inputbar `#E4DED0`, notification accent `#A8C0D5`, highlight inactive `#A8C0D5` / active `#4A6F8E`). Font `Terminess Nerd Font Mono 11` (нативный bitmap-размер). `adjust-open = width` для нормального первого paint'а. Recolor mode (`r`) выключен по дефолту — `recolor-keephue=true` если включат. Бэкэнд **mupdf** (`zathura-pdf-mupdf`) — PDF / ePub / XPS / CBZ / FB2 одним плагином (только один бэкэнд может быть активен одновременно). `install.sh` (sudo): `pacman -S --needed zathura zathura-pdf-mupdf` + `xdg-mime default org.pwmt.zathura.desktop` для PDF/ePub/oxps/xps/comicbook/cbz/cbr (раньше PDF открывался в firefox). `CHEATSHEET.txt` = сток-бинды (hjkl/J-K/gg-G/+−/a-s/f-F-links/r-recolor). `.stow-local-ignore` есть (см. секцию выше). zathura — GTK3, диалоги open/save наследуют тему из `gtk/`-пакета автоматически.

**obsidian** (2026-05-24, todo #16): `obsidian/` НЕ stow — конфиг живёт per-vault (`~/Documents/Obsidian/second_brain/.obsidian/`), не XDG. `install.sh` (sudo для pacman) симлинкует три файла + jq-патчит два:
  - `sky-paper.css` → `<vault>/.obsidian/snippets/sky-paper.css` (CSS snippet)
  - `vimrc` → `<vault>/.obsidian.vimrc` (CodeMirror 6 vim, через 'Vimrc Support' community-plugin)
  - `hotkeys.json` → `<vault>/.obsidian/hotkeys.json` (app-level Ctrl-чорды)
  - `appearance.json`: `theme="obsidian"` (force light), `cssTheme=""` (Default theme), `accentColor="#4A6F8E"`, `enabledCssSnippets += "sky-paper"`
  - `community-plugins.json`: `+= "obsidian-vimrc-support"` (сам плагин-bundle юзер ставит руками из marketplace, marketplace через CLI не достаётся)

**🔴 Тема — Obsidian DEFAULT, НЕ Minimal.** Minimal был выбран первым (CSS-vars overlay поверх Minimal), но без Style Settings плагина Minimal полностью удаляет `.workspace-tab-header-inner-title` элемент для inactive-tab — CSS не может покрасить то, чего нет в DOM (даже high-specificity diagnostic deep-sky color не показывался). Diagnostic: переключение `cssTheme: ""` + Sky Paper только через vars → всё видно. Все vars (`--background-*`, `--text-*`, `--code-*`, `--tab-text-color`, `--titlebar-background`, `--ribbon-background` и т.д.) сидят в одном `.theme-light {...}` + `body {...}` блоке, без selector-level forcing. Code-block синтаксис мапится на nvim Sky Paper роли в обоих режимах: reading-mode (`.token.*` Prism) и live-preview (`.cm-*` CodeMirror 6).

**🔴 Vimrc CM6 quirks (НЕ Neovim):** `:let mapleader` игнорируется, `:set langmap` игнорируется, `noremap`/`nnoremap`/`xnoremap` НЕ работают — только `nmap`/`vmap`/`imap`. Поэтому vimrc минимальный: `<Esc>:nohlsearch`, visual `p "_dP`, `+`/`-` increment, arrows nopped, `<C-a>` → `ggVG` (select-all). Всё, что в nvim было через `<leader>` — переехало в `hotkeys.json` как Ctrl-чорды. Файл/поиск (Ctrl+O switcher, Ctrl+Shift+F global, Ctrl+P palette), markdown editing (Ctrl+B bold, Ctrl+I italic, Ctrl+1..6 set heading, Ctrl+0 remove heading) — Obsidian-defaults оставлены. Добавлены: Ctrl+\` toggle-code, Ctrl+Alt+] heading-up, Ctrl+Alt+[ heading-down, Ctrl+\ toggle-sidebar.

LSP-binds (`gd`/`gr`/`K`/`<leader>rn`/`<leader>ca`), gitsigns (`]c`/`[c`/`<leader>h[prb]`), DiffView (`<leader>g*`), терминал (`<leader>t/q`) из nvim НЕ зеркалятся — нет Obsidian-аналога. CHEATSHEET перечисляет «NOT MIRRORED» явно. Полные подробности — `~/dotfiles/obsidian/CHEATSHEET.txt`.

`.stow-local-ignore` есть (см. секцию выше) — пакет stow'ится как no-op (всё через install.sh), но safe-by-default если кто-то прогонит `stow obsidian` рефлекторно.

🔴 **Obsidian rewrites appearance.json + community-plugins.json + hotkeys.json on shutdown** — `install.sh` проверяет `pgrep -x obsidian` и отказывается работать с запущенным Obsidian (иначе in-memory state затрёт наш патч на close). Поскольку hotkeys.json теперь symlink в репо, любое редактирование hotkeys через Obsidian UI приземляется как `git diff` в `obsidian/hotkeys.json` — review / commit / revert по обычным правилам.

**install.sh-пакеты (НЕ stow):** `quickshell-greeter`, `keyd`, **`nftables`**, **`sshd`**, **`sysctl`**, **`tlp`**, **`obsidian`** — деплоятся скриптом (sudo если нужно), не stow. `keyd`/`nftables`/`sshd`/`sysctl` ставят root-owned `/etc/`-конфиги; `tlp` = drop-in `/etc/tlp.d/00-aru.conf`; `obsidian` симлинкует CSS-сниппет + vimrc + hotkeys.json в `~/Documents/Obsidian/<vault>/.obsidian/` (per-vault конфиг, не XDG).

**Доп. системные файлы из `quickshell/` (ставятся вручную, не stow, не install.sh):** `~/.config/quickshell/{bluetooth-toggle.rules → /etc/polkit-1/rules.d/49-bluetooth-toggle.rules, epp-toggle.rules → 49-epp-toggle.rules, set-epp → /usr/local/bin/set-epp}` — версионируются в quickshell-пакете, инструкция установки в шапке каждого файла.

**Симлинки (проверено 2026-05-17):** `~/.config/kitty/kitty.conf` — per-file symlink. `~/.config/regreet` — **directory-level symlink** на `~/dotfiles/regreet/.config/regreet/` (НЕ regular files, как раньше писалось в CONTEXT). Поэтому редактирование через любой из путей правит один и тот же файл. **Watch out:** `ln -s` с destination внутри `~/.config/regreet/` создаст симлинк ВНУТРИ dotfiles — может затереть реальные файлы. Использовать Write tool на любой из путей. (`~/.config/waybar` был таким же directory-symlink — снят вместе с waybar 2026-05-21.)

---

## Working style with Арсом (read carefully)

**Арс — junior инженер**, осваивает Linux sysadmin.

- **НЕ давать готовые код-блоки для копирования** в обычных configs (KDL/YAML/INI). Описывать поля/значения. Арс пишет сам.
- **Цвета/палитра — исключение.** Арс прямо сказал «это чисто мануал работа», Claude применяет hex'ы сам.
- **Шрифты — тоже исключение** после длинной итерации 2026-05-17. Claude применяет font configs сам, Арс reacts.
- **Boilerplate momentum** (pacman, AUR, systemctl): не растягивать педагогикой.
- **Diffs first** на config-sync задачах. Не редактировать preemptively.
- **Commits** — описательные, не амендить.
- **Не итерировать палитру без явного направления** — было 6 swap'ов. Спрашивать чётко.
- **Не итерировать font без направления** — было 5 swap'ов 2026-05-17. Спрашивать чётко.

---

## Phase status

- ✅ Phase 0 — Discovery
- ✅ Phase 1 — Foundational packages + services (минус tlp.conf, fwupd timer verify)
- 🟡 Phase 2 — niri config (focus/border/opacity/swaybg done; input/binds не сделаны; startup overlay skipped)
- 🟡 Phase 3 — terminal/shell/editor (kitty/tmux/nvim done с Terminess+Unifont; fish установлен но статус chsh неясен)
- 🟡 Phase 4 — Bar + login manager (waybar done с новым config.jsonc; regreet шрифт обновлён; walker/swaync не настроены)
- ⬜ Phase 5 — eww widgets
- 🟡 Phase 6 — Laptop-specific (BT picker через CC; swayidle + Quickshell-локер СДЕЛАНО+верифицировано+смержено 2026-05-20; TLP 85/90 + CC EPP-цикл СДЕЛАНО+верифицировано на ветке `tlp-power-cc`, не смержена)
- ⬜ Phase 7 — dotfiles финализация (commit, push, README, ASCII wallpaper)

---

## Open issues / pending decisions

**Resolved 2026-05-17 session:**
- ✅ Font direction — Terminess Nerd Font Mono + Unifont italic. Применено в kitty/waybar/regreet.
- ✅ Waybar config.jsonc — recreated с нуля (был удалён). Workspaces/clock с calendar/lang+net+pa+battery с glyphs. Click на lang → switch-layout next.
- ✅ Niri startup overlay — `hotkey-overlay { skip-at-startup }` включено.

**Pending:**
1. **niri binds** — кастомизация под Mod+T/D/Shift+E (план).
2. **ASCII art wallpaper** — план A (angel/cherub jp2a from painting) не выполнен.
3. ✅ **TLP config** — РЕШЕНО 2026-05-19: drop-in 85/90 charge-thresholds установлен+верифицирован; CC EPP-цикл готов. Ветка `tlp-power-cc` ждёт Арсова ревью+мержа (`git branch -f laniakea tlp-power-cc`, fast-forward). EPP-дефолты сознательно не трогали.
4. **Global `~/.claude/CLAUDE.md`** — отсутствует.
5. **fwupd-refresh.timer** — `active (waiting)`, но рефрешит **только metadata**, прошивки сам не ставит. Если нужен реальный auto-apply — `fwupd-refresh.service` + ручной `fwupdmgr update` либо отдельный таймер.
6. **Commits** — на ветке `laniakea` ни одного коммита с начала Phase 3. Всё uncommitted. master HEAD: `57f9759`.
7. **Fish prompt** — tide vs starship, не решено.
8. **ControlCenter runtime** — Wifi-ряд юзером подтверждён (scan/list/h-l/power-toggle/disconnect). Не гоняны end-to-end: footer power-actions, Volume mute, Brightness/Warm/Airplane через hjkl, password-flow секьюрной сети. Регрессию искать в `cc`-инъекции (шов Tier 2). `nmcli con down id "<ssid>"` предполагает имя профиля == SSID (дефолт NM); при ручном переименовании профиля disconnect не сматчит → fallback на disconnect интерфейса.

---

## Files map

- `~/dotfiles/` — repo, branch `laniakea`. Remote: `origin/laptop` (старая), `origin/master` (celestia)
- `~/dotfiles/CLAUDE.md` → `@CONTEXT.md`
- `~/dotfiles/CONTEXT.md` — этот файл
- `~/dotfiles/PALETTE.md` — Sky Paper канон
- `~/dotfiles/palette-lotus.md` — kanagawa lotus архив
- `~/.config/fontconfig/conf.d/10-terminus-alias.conf` — alias `Terminus` → `Terminus (TTF)` (если Terminus вернёмся)
- `~/.config/quickshell/bluetooth-toggle.rules` — polkit-правило для BT-toggle (версионируется, ставится вручную в `/etc/polkit-1/rules.d/49-bluetooth-toggle.rules`)
- `~/.config/quickshell/{set-epp, epp-toggle.rules}` → `/usr/local/bin/set-epp` (0755) + `/etc/polkit-1/rules.d/49-epp-toggle.rules` (0644). Sudo-install вручную (инструкция в шапке файлов). Даёт `Power.qml` password-less `pkexec` смены EPP. Установлено+верифицировано 2026-05-19.
- `~/dotfiles/keyd/etc/keyd/default.conf` + `keyd/install.sh` → `/etc/keyd/default.conf` (sudo, root-owned, НЕ симлинк). CapsLock→f19 = nvim leader; Shift+Caps = реальный CapsLock.
- `~/dotfiles/nftables/etc/nftables.conf` + `etc/nftables.d/00-filter.nft` + `nftables/install.sh` → `/etc/nftables.conf` + `/etc/nftables.d/` (sudo, root-owned, НЕ симлинк). inet drop-by-default + DHCP-allow выше invalid-drop.
- `~/dotfiles/sshd/etc/ssh/sshd_config.d/00-hardening.conf` + `sshd/install.sh` → `/etc/ssh/sshd_config.d/00-hardening.conf` (sudo, root-owned, НЕ симлинк). Key-only, no root, no X11.
- `~/dotfiles/sysctl/etc/sysctl.d/99-hardening.conf` + `sysctl/install.sh` + `README.md` → `/etc/sysctl.d/99-hardening.conf` (sudo, root-owned, НЕ симлинк). kptr_restrict + rp_filter + ignore/no-emit ICMP redirects + syncookies. `ip_forward` закомментирован (включить при Docker/libvirt-routed).
- `~/dotfiles/tlp/etc/tlp.d/00-aru.conf` + `tlp/install.sh` → `/etc/tlp.d/00-aru.conf` (sudo, root-owned, НЕ симлинк). Charge-thresholds 85/90 BAT0, override-only drop-in. На ветке `tlp-power-cc` (не смержена в laniakea).
- `~/dotfiles/swayidle/.config/swayidle/{config,README.md}` → `~/.config/swayidle/` (stow, dir-symlink). Idle: 5м dim → 10м lock+screen-off → 30м suspend. Все три lock-хука: `qs ipc call lock lock`. 🔴 нет `\` line-continuation.
- `~/dotfiles/quickshell/.config/quickshell/{LockScreen,LockBox,LockClock,Field}.qml` — Quickshell-локер (`WlSessionLock` + `PamContext` + `IpcHandler{target:"lock"}`). Триггер: `qs ipc call lock lock` или `qs ipc call lock unlock` (debug-escape). См. «🔒 Session 2026-05-20» выше.
- `~/dotfiles/quickshell-greeter/.config/quickshell-greeter/BigClock.qml` — greeter-копия `LockClock` (greeter-юзер не читает `/home/aru`, поэтому дубль). `Greeter.qml` + `LoginBox.qml` зеркалят lock-state-machine asleep→awake→revealed.
- `~/Pictures/wallpapers/clouds.png` — Ghibli sky обоина
- `~/.config/<app>/` — kitty/niri/nvim/tmux симлинки на dotfiles; regreet — directory-symlink (см. секцию «Симлинки» выше)

---

## First moves for new Claude session

1. **Прочитать `~/dotfiles/CONTEXT.md` и `PALETTE.md`** (вероятно загружены через CLAUDE.md auto-import).
2. **Font стек fixed** — не итерировать без явного направления.
3. Quick state: `systemctl is-active greetd keyd; niri msg outputs 2>&1 | head; pacman -Q | grep -E "regreet|cage|swaybg|keyd"`.
4. **Watch out:** `~/.config/regreet` — directory symlink в dotfiles. Не запускать `ln -s` с destination внутри него — затрёт реальные файлы.
