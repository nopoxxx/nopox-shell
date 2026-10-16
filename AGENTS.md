# nopox-shell — описание проекта для агентов

> **Правило для любого агента и человека, меняющего проект:**
> этот файл — карта проекта. **Любое изменение кода, которое делает описание здесь неверным или неполным,
> должно в том же коммите обновить `AGENTS.md`**: новые/удалённые/переименованные файлы, модули панели,
> настройки, IPC-команды, пути хранения, форматы данных, соглашения, подводные камни.
> Перед завершением задачи перечитай затронутые разделы и сверь их с кодом.
> Если изменение пользователю видно — обнови документацию `docs/index.html` (сайт на GitHub Pages),
> а если оно меняет установку или главные клавиши — и короткий `README.md`.

## 1. Что это

Оболочка рабочего стола для композитора **niri** (Wayland), написанная на **Quickshell** (QML + JS).
Весь интерфейс стилизован под терминал: панель — строка shell-приглашения, меню — fzf,
настройки — menuconfig, уведомления — строки лога, блокировка — getty. Палитра Gruvbox dark hard,
шрифт `Terminess Nerd Font Mono`. Целевая система — Arch Linux и производные (pacman, paru).

- Язык интерфейса, комментариев, README и документации — **русский**. Сообщения коммитов — **английский**,
  формат `Area: what changed` (например `Binds window: …`, `install.sh: …`).
- Репозиторий: `https://github.com/nopoxxx/nopox-shell`, ветка `main`.
- Установлен у пользователя как git-клон в `~/.config/quickshell` (Quickshell грузит `shell.qml` оттуда).
- Сборки, тестов и линтера нет. Проверка — запуск в живой сессии niri.

## 2. Запуск и проверка

```sh
pkill -x qs; niri msg action spawn -- qs   # перезапустить shell (так же делает Mod+S → system/ → перезапустить shell)
qs ipc call <target> <function>             # дёрнуть IPC (таблица в §6)
niri validate -c ~/.config/niri/config.kdl  # проверить сгенерированный конфиг niri
NOPOX_GREETER=1 qs -p /usr/share/nopox-shell/greeter.qml   # greeter (обычно запускает greetd)
```

Из SSH (вне сессии) `qs ipc`/`qs list` экземпляр не видят — ищут на своём Wayland-дисплее:
нужен `WAYLAND_DISPLAY=wayland-1` (или `qs ipc --pid $(pgrep -x qs) call …`).
Quickshell перезагружает конфиг при изменении `.qml`-файлов сам, а при изменении только `.js`
(например `services/settings.js`) — нет: нужен перезапуск `qs`. Ошибки QML и `console.warn` видны в выводе `qs`.
Модули импортируются как `qs` (корень), `qs.services`, `qs.bar` — это имена каталогов.

## 3. Дерево файлов

```
shell.qml            корень ShellRoot: Background и Bar на каждый экран, остальные окна по одному
Theme.qml            синглтон: палитра, accent (из shell.accent), шрифт, fontSize, barHeight, pad
T.qml                базовый Text (шрифт/цвет темы, NativeRendering) — использовать вместо Text
Bar.qml              PanelWindow панели: три BarZone, автоскрытие, floating-стиль, openPopups
BarZone.qml          Row модулей по списку id; Loader по bar/<file>.qml; разделители между видимыми
TuiPopup.qml         PopupWindow в TUI-рамке с заголовком [ title ] — база всех попапов панели
Background.qml       обои на слое Background (namespace nopox-wallpaper), плавная смена, fill/fit/stretch
Launcher.qml         меню Mod+D — только действия: apps/ wallpaper setup packages/ system/ about; провайдеры, нечёткий поиск
WallPicker.qml       выбор обоев: local и wallhaven, сетка превью, бесконечная прокрутка
HomePanel.qml        меню home — панель во всю высоту у края: секции home/ по shell.home.layout, фокус с клавиатуры
OsdWindow.qml        индикатор громкости и яркости при изменении (namespace nopox-osd, клики насквозь)
CalGrid.qml          месяц как `cal` — общий для CalPopup и секции календаря в home
ClipboardWindow.qml  история буфера (cliphist): список с поиском слева, запись целиком справа (текст/картинка)
ShotWindow.qml       скриншот с разметкой (по мотивам rishot, MIT): заморозка экранов, область/экран/окно, инструменты, экспорт
SettingsWindow.qml   окно настроек в стиле menuconfig: строки из S.sections(), поиск (/), действия — runAction()
DisplaysWindow.qml   мониторы: карта, режим/масштаб/поворот/расположение/VRR/основной, откат через 15 с
BindsWindow.qml      бинды niri: список с поиском, редактор (сочетание/действие/подпись), конфликты
NotifPopups.qml      стопка всплывающих уведомлений (namespace nopox-notify)
NotifCard.qml        карточка уведомления: рамка цвета уровня, печать заголовка, полоска таймера
LockScreen.qml       WlSessionLock + PAM (/etc/pam.d/login), предпросмотр, IdleMonitor
LoginPrompt.qml      общий экран getty (часы, login:, Password:) для блокировки и greeter
BigClock.qml         часы из блоков 3×5 как tty-clock
BlinkCursor.qml      мигающий █
EditField.qml        поле ввода в рамке с подписью (используется в BindsWindow)
GreeterSync.qml      копирует настройки/обои в /var/lib/nopox-greeter/$USER для greeter
greeter.qml          отдельная точка входа greeter для greetd (ShellRoot, Greetd)

services/            синглтоны (pragma Singleton) и JS-библиотеки
  Settings.qml       settings.json + генерация ~/.config/niri/nopox/*.kdl; outputs из niri; миграция
  settings.js        СХЕМА НАСТРОЕК, умолчания, модули панели, генерация KDL, termCmd, бинды — центр проекта
  Niri.qml           состояние niri из `niri msg --json event-stream`; action(), focusWorkspace()
  Sys.qml            cpu/mem/net/gpu/temp из /proc и /sys раз в 2 с; user, host, kernel
  Binds.qml          объединённые бинды (config.kdl + nopox/binds.kdl + свои), keys.kdl, validate и откат
  Wallpaper.qml      текущие обои, режим заполнения, локальная коллекция, wallhaven API, загрузка
  Notifs.qml         NotificationServer: история (до 100), попапы (ListModel ключей), DND, IPC notify
  ShellUpdate.qml    git fetch/pull самого shell, список новых коммитов, перезапуск, обновление greeter
  Updates.qml        число обновлений (checkupdates + paru -Qua) раз в час, запуск paru -Syu
  Term.qml           выбранный терминал: Term.open(argv), Term.float(argv, {hold}), Term.edit(path), Term.cmd(), configPath
  AppTheme.qml       темы GTK и Qt вслед за shell: пишет S.themeFiles() в ~/.config и S.themeGsettings() в gsettings
  MuteNotify.qml     уведомление при мьюте микрофона/звука по умолчанию (PipeWire, любым способом), shell.notify.mute
  Clipboard.qml      cliphist: один `wl-paste --watch cliphist store` пока жив shell (прежние гасит pkill); entries, copy, remove, wipe
  Home.qml           открыто ли меню home и на каком мониторе; IPC home
  Weather.qml        Open-Meteo: место (город → геокодер, пусто → ipinfo.io), current, daily, sun; раз в 30 мин
  NightLight.qml     gammastep -O / -l по закату, пока shell.night.on; держится процессом
  Recorder.qml       wf-recorder: область (slurp) или монитор, звук, SIGINT — стоп; IPC record
  Brightness.qml     /sys/class/backlight: value, set() через brightnessctl; опрос 400 мс
  glyphs.js          значки Nerd Font по именам: G.g("wifi"); рисовать Theme.iconFont
  DefaultApps.qml    оболочка входа и браузер по умолчанию (shell.sh, shell.browser): сверка с системой, chsh, xdg-settings
  fuzzy.js           match(query, str) → {score, pos} | null; highlight(str, pos, color) для StyledText

bar/                 модули панели и их попапы
  Seg.qml            базовый сегмент «label value» + сигналы leftClicked/rightClicked/middleClicked/scrolled (при scrollable)
  User Workspaces Jobs Command          inline-модули (часть «приглашения»)
  Media Tray Cpu Mem Gpu Temp NetSpeed Net Vol Bat Upd ShellUpd Notify Kbd Clock
  Rec Home           ● REC во время записи; значок меню home (для тех, кто убрал user@host)
  CalPopup ProcsPopup MixerPopup VolBar TrayMenu NotifyCenter ShellUpdPopup   попапы/части

home/                секции меню home (HomePanel): Section.qml — база, Btn.qml — [кнопка], Gauge.qml — ползунок
  User Quick Levels Media Weather Calendar Notifs System Power Wifi Bluetooth Actions

extras/              не грузится shell'ом; эталонные конфиги для install.sh и ручной установки
  niri/config.kdl    полный config.kdl nopox (свои бинды niri; include nopox/main.kdl в начале, nopox/keys.kdl в конце)
  niri/nopox/*.kdl   стартовые заглушки ~/.config/niri/nopox/ (shell перезапишет при запуске)
  niri.kdl           инструкция по ручному подключению к своему config.kdl
  greeter/niri.kdl   конфиг niri для greeter (/etc/greetd/nopox-niri.kdl)
  install-greeter.sh sudo: копия shell в /usr/share/nopox-shell, каталоги синхронизации, greetd
  kitty/ alacritty/ ghostty/ foot/   конфиги терминалов в Gruvbox + Terminess
  fastfetch/config.jsonc  fastfetch в стиле панели; его же берёт about в меню (с акцентом shell)
  shell/             zshrc, fish_prompt.fish, nopox.fish, bashrc — приглашение как у панели
install.sh           установщик для Arch (вопросы → итог → установка), см. §10
README.md            коротко: что это, установка, главные клавиши, ссылка на документацию
docs/                документация — GitHub Pages из main /docs (https://nopoxxx.github.io/nopox-shell/)
  index.html         одна страница без сборки: стили и JS внутри, макеты экранов shell нарисованы текстом
  fonts/             Terminess (Regular/Bold), урезанный pyftsubset до латиницы, кириллицы, псевдографики и пары
                     значков трея (~12 КБ), + LICENSE.txt (OFL); новый символ вне набора — пересобрать подмножество
```

## 4. Архитектура и потоки данных

### 4.1 Настройки (`services/Settings.qml` + `services/settings.js`)

- Хранение: `~/.config/nopox/settings.json` — **только отличия от умолчаний**, плоские ключи.
  `Settings.get(key)` → значение или `S.defaultOf(key)`. `Settings.set(key, v)` — если `v` равно
  умолчанию, ключ удаляется. `reset(key)`, `isDefault(key)`, `replacePrefix(prefix, obj)`,
  `snapshotPrefix(prefix)` (для отката мониторов).
- Сохранение — с задержкой 250 мс (таймер `save`): пишет JSON (`atomicWrites`) и вызывает `writeNiri()`.
- Загрузка: файла нет — умолчания, первое сохранение его создаст. Файл есть, но не читается (битый/пустой JSON —
  после трёх перечитываний через 300 мс, нет прав) — `Settings.broken`: работаем на умолчаниях, ничего не пишем,
  critical-уведомление. **Любая запись по настройкам** (settings.json, `nopox/*.kdl`, keys.kdl, темы, chsh)
  проверяет `Settings.writable` (`loaded && !greeterMode && !broken`) — иначе пустые значения затрут файлы.
- `writeNiri()` строит файлы через `S.niriFiles(get, outs)` и пишет **только изменившиеся**
  (кэш `_written`), через временный файл и `mv` (niri перечитывает конфиг на каждую запись).
- Префиксы ключей: `niri.*` — уходят в конфиг niri; `shell.*` — читает QML; `wallpaper.*` — особые
  (заполнение хранит сервис Wallpaper, не Settings).
- Особые ключи вне схемы `sections()`:
  - `shell.bar.layout` — `{left:[], center:[], right:[], off:[]}`, умолчание `DEFAULT_LAYOUT`;
    всегда читать через `S.normalizeLayout()` (добавит новые модули в их зону по умолчанию).
  - `niri.keys` — свои бинды `{ comboKey: {combo, action, title} }`; `action: "off"` — отключить.
  - `niri.out.<output>.<prop>` — мониторы: `enabled, mode, scale, transform, x, y, vrr, primary, place`
    (`place` — `auto` или `right|left|above|below:<output>`, из него пересчитываются x/y).
- `Settings.outputs` — нормализованный `niri msg --json outputs` (name, modes, mode, preferred, scale,
  transform, x, y, w, h, enabled, vrrSupported, vrr…). Обновляется `refreshOutputs()`.
- Greeter-режим (`NOPOX_GREETER=1`): файл — `/var/lib/nopox-greeter/<profile>/settings.json`,
  только чтение, `writeNiri` ничего не делает.
- Миграция старой схемы (`nopox.kdl`, `nopox-binds.kdl`, `nopox-keys.kdl` рядом с config.kdl) —
  процесс `migrate` после первой записи; при неудачном `niri validate` возвращает config.kdl.

**Схема окна настроек** — `S.sections(outputs, layout, home)`: массив `{id, title, rows}`. Разделы — по тому,
что ищет пользователь, а не по тому, кто читает настройку (niri или shell):

| id | title | что внутри |
|---|---|---|
| `look` | вид | акцент, размер шрифта; темы Qt/GTK и шрифт в приложениях; обои (выбрать, wallhaven, заполнение); строк в меню; индикаторы (OSD) |
| `windows` | окна | отступы, колонки, рамка фокуса, обводка, тени, скругление, прозрачность неактивных, CSD, анимации |
| `input` | ввод | клавиатура; клавиши (бинды, подсказка niri, мьют); горячие углы; мышь и тачпад; курсор |
| `bar` | панель | модули по зонам; панель; prompt; вид модулей (часы, график cpu, трей) |
| `home` | меню home | секции (показаны / скрыты, порядок); край и ширина; погода; ночной режим; запись экрана |
| `notify` | уведомления | DND, положение, время, максимум, критичные, эффект набора |
| `lock` | блокировка | idle, эхо пароля, часы, обои, предпросмотр, заблокировать |
| `system` | система | устройства (мониторы, сеть, звук); приложения: терминал, файловый менеджер, оболочка, браузер; скриншоты; конфиги; nopox-shell (обновить, проверка, перезапуск, greeter) |

Новую настройку кладите туда, где её будут искать; раздел и группу (`header`) поиск тоже учитывает.
Строка — `{header}` или `{key, label, type, def, hint, …}`. Типы:

| type | поля | поведение |
|---|---|---|
| `bool` | `def` | ←→ / Space / клик — переключить в черновик |
| `int`, `float` | `min, max, step, def` | ←→ ± step в черновик, float округляется до 2 знаков |
| `enum` | `options, def` | ←→ по кругу в черновик |
| `text` | `def` | ↵ — поле редактирования |
| `action` | `action` | ↵ — действие; строится `act(name, label, hint)`, ключ `action.<name>` (значения нет); обработчик — `switch` в `SettingsWindow.runAction()` |
| `module` | `id, zone, zoneLabel, key` | элемент раскладки (`layoutRows(key)`: модули bar/, секции home/): ←→ — зона в черновик, ↵ — применить (`S.setZone`), r — зона по умолчанию; ⇧↑↓ / K/J — порядок, сразу; `key` — чья раскладка, черновик — по `key` и `id` |
| `combo` | `def: "", action` | сочетание клавиш: ↵ — захват нажатия (`Binds.comboOf`), ⇥ — ввод текстом (занятое niri сочетание окну не нажать), ⌫ — убрать; `action` — строка KDL, по ней `Binds.conflict` ищет чужие бинды на том же сочетании |

`S.niriFileOf(key)` — в каком файле `nopox/` живёт настройка (показывается в подсказке).

### 4.1a Темы приложений (`services/AppTheme.qml`, генерация — в `settings.js`)

Настройки `shell.theme.sync` (вкл/выкл) и `shell.theme.font` (шрифт shell в интерфейсе приложений);
цвета — `GRUVBOX` + `ACCENTS[shell.accent]`, размер — `shell.fontSize` (px × 0.75 → pt), курсор — `niri.cursor.size`.

- `S.themeFiles(get, home)` → `{ путь от ~/.config: текст }`:
  `gtk-3.0/nopox.css` (`@define-color` именованных цветов libadwaita — их понимает тема adw-gtk3),
  `gtk-4.0/nopox.css` (то же + CSS-переменные `--window-bg-color` в `:root`: libadwaita ≥ 1.6 читает их),
  `qt6ct/colors/nopox.conf` (22 роли QPalette по порядку, от WindowText до Accent),
  `qt6ct/qt6ct.conf` (Fusion, своя палитра, иконки `ICONS`, шрифты в формате `QFont::toString`).
  Синхронизация выключена → `nopox.css` пустые, qt6ct не трогается.
- `S.themeGsettings(get)` → `[[ключ org.gnome.desktop.interface, GVariant | "" — reset]]`:
  `color-scheme`, `gtk-theme adw-gtk3-dark`, `icon-theme` (`ICONS` = Gruvbox-Plus-Dark из AUR `gruvbox-plus-icon-theme`), `accent-color` (через `GNOME_ACCENTS`, aqua → teal),
  `cursor-size`, шрифты. Синхронизация выключена → пустой список: gsettings не трогаем вовсе.
- `AppTheme` сериализует оба результата в `state` и пишет, только когда строка изменилась (задержка 500 мс);
  `@import "nopox.css";` стоит **последним среди `@import`** в `gtk.css` (до остальных правил — иначе GTK проигнорирует
  @import): из одинаковых `@define-color` побеждает последний, и остатки других тем (например `noctalia.css` от Noctalia)
  перебивали палитру. При каждой записи импорт переставляется, если после него появился чужой.
- `S.APP_ENV` (`QT_QPA_PLATFORMTHEME=qt6ct`) — блок `environment` в `misc.kdl` при `shell.theme.sync`. niri выдаёт его только
  тому, что запустит после этого, поэтому программы, которые запускает сам shell (меню — `execDetached` с
  `DesktopEntry.command` вместо `entry.execute()`, терминалы — `Term.run`), получают окружение явно: `Settings.appEnv()`;
  при выключенных темах переменная убирается, только если её поставили мы (`=qt6ct`).
- Уже открытые GTK-окна новый CSS не перечитывают (проверено: переключение gtk-theme туда-обратно не помогает) —
  только после перезапуска приложения. Новые окна получают изменения сразу.

**Черновик.** Значения (`bool`, `enum`, `int`, `float`) меняются не сразу: ←→, Space, клик и `r` (по умолчанию) пишут
`win.draft = {key, value}` (`propose`), строка показывает `было → ‹ станет ›` и кнопку `[↵]`; применяет только ↵
(`activate` → `apply`), Esc или смена строки (`onCurChanged`) — отменяют. ↵ без черновика значение не меняет.
`text` и `combo` и так подтверждаются ↵; строки модулей bar/ (зона, порядок) меняются сразу.

**Окно настроек.** Открытый раздел помнит `Settings.page` (окно возвращается к нему); `Settings.show(id)`
открывает нужный, IPC `settings open <id>`. `/` — поиск: `S.searchRows(sections, query)` ищет каждое
слово в подписи, подсказке, ключе (у модулей — id), группе и разделе; результаты под заголовками
`раздел/ · группа`, Esc сбрасывает. `runAction()` закрывает настройки; для окон binds, displays, picker,
wallhaven, lockPreview ставит `Settings.returnHere` — закрываясь, такое окно зовёт `Settings.back()`
и настройки открываются снова. Новое окно-действие должно делать так же (`onOpenChanged: if (!open) Settings.back()`).

### 4.1b Оболочка и браузер (`services/DefaultApps.qml`)

`shell.sh` (`S.SHELLS`, пакеты — `S.SHELL_PKGS`) и `shell.browser` (`S.BROWSERS`: id → `{pkg, bin}`, `none` — без бинда)
отражают **состояние системы**, а не только выбор: при старте и после каждого применения `probe` читает
оболочку из `getent passwd`, браузер — `xdg-settings get default-web-browser` (сопоставляется с `.desktop`
установленных пакетов из `pacman -Qlq`) и пишет их в настройки (неизвестный браузер не трогает).
Изменение настройки применяется через 1.5 с (таймер, чтобы ←→ не запускали chsh на каждом шаге) одним
скриптом `applyScript` с данными в аргументах: оболочка — в терминале `nopox-term` (`pacman -S`, если нет; конфиг nopox
из `extras/shell`, если своего нет; `chsh -s`), браузер — `xdg-settings set` молча или через `paru -S` в терминале.
Отменённый chsh / неудачная установка — следующий `probe` вернёт настройку к системе.
`Mod+Shift+B` в `binds.kdl` запускает `BROWSERS[shell.browser].bin`.

### 4.2 Конфиг niri (`~/.config/niri/`)

```
config.kdl            пользовательский; include "nopox/main.kdl" и В САМОМ КОНЦЕ include "nopox/keys.kdl"
nopox/main.kdl        include остальных: input displays layout window-rules cursor animations misc binds
nopox/input.kdl …     генерирует Settings из S.niriFiles() — вручную не править
nopox/binds.kdl       spawn-at-startup "qs" + бинды nopox (Mod+Return, Mod+E, Mod+Shift+B, Mod+D, Mod+Space, Mod+Shift+W, Mod+Shift+V, Mod+A, Mod+Alt+R, Mod+Shift+S, Print, Mod+S, Super+Alt+L)
nopox/keys.kdl        свои бинды из окна биндов — пишет Binds.qml (S.keysKdl), подключён последним → перекрывает
```

В одном KDL-файле может быть только один блок `binds`, поэтому всё nopox — во включаемых файлах.
`layout.kdl` ставит `background-color "transparent"`; window-rules делают окна `nopox-term`
(ghostty: `dev.nopox.term`) плавающими 960×600 и кладут слой `nopox-wallpaper` в backdrop обзора.
В строках KDL нельзя `\.` — используется `[.]`. Вложенный блок KDL закрывать с переводом строки
(`a { b { c } }` в одну строку niri не разберёт).
Горячие углы — `niri.hc.*` → `gestures { hot-corners { … } }` в `misc.kdl` (`HOT_CORNERS`); ни одного — `off`,
потому что пустой блок niri считает «по умолчанию» (левый верхний).

### 4.3 Бинды (`services/Binds.qml`, `BindsWindow.qml`)

- `Binds.all` — карта по `S.comboKey(combo)` (регистр и порядок модификаторов не важны,
  Control=Ctrl): config.kdl → поверх nopox/binds.kdl → поверх свои. `source`: `config|nopox|own|changed`.
- `S.parseBinds(text)` понимает только однострочные бинды внутри `binds { }`.
- `S.actionKdl()` переводит ввод человека в KDL: `spawn kitty` → `spawn "kitty"`,
  `spawn kitty -e btop` → `spawn-sh "kitty -e btop"`, числа без кавычек, с кавычками — как есть.
- После записи keys.kdl (300 мс) — `niri validate`; при ошибке `Binds.error` и откат к `_prevKeys`.
- `replaceKey(old, new, …)`: старое сочетание из конфига — отключается (`off`), своё — удаляется.
- Отключение = `Combo hotkey-overlay-title=null { spawn "true"; }`.
- Список действий niri — из `niri msg action --help`; пресеты nopox — `BindsWindow.presets`.
- `Binds.keyName(key, text)` (Qt-клавиша → keysym niri) и `Binds.comboOf(event)` — общие для окна биндов и строк `combo`.
- Свои сочетания из настроек — `MUTE_BINDS` в settings.js (`niri.key.micMute`, `niri.key.audioMute` → `wpctl set-mute`
  источника/приёмника по умолчанию, `allow-when-locked`): пишутся в `binds.kdl`, только если значение проходит `COMBO_RE`.

### 4.4 Панель

- `shell.qml` создаёт `Bar` на каждый экран (или только `screens[0]` при `shell.bar.monitors = primary`).
  У каждой панели **свои экземпляры модулей и попапов**.
- `BarZone` грузит `bar/<file>.qml` через `Loader.setSource(url, {bar})`. Импорт `qs.bar` в BarZone
  нужен, чтобы Quickshell просканировал каталог.
- **Колёсико по панели** листает столы её монитора (`Bar.scroll()` → `Niri.scrollWorkspace(output, dir)`,
  настройка `shell.bar.wheelWorkspaces`). Обработчик — `MouseArea` с `acceptedButtons: Qt.NoButton` под зонами
  (не `WheelHandler` на фоне: он событие не получал). Тачпад копится до шага 120. Модуль, которому колёсико
  нужно самому, ставит `scrollable: true` (Seg) и принимает событие; остальные `MouseArea` без `onWheel`
  или `Seg` без `scrollable` его пропускают — `wheel.accepted = false`.
- **Контракт модуля**: корневой элемент имеет `property var bar` и `property bool available`
  (false — модуль скрыт и не порождает разделитель). Большинство модулей — `Seg { label; value; valueColor; bold }`
  с сигналами кликов/колёсика. Разделитель между модулями — `shell.bar.separator`, между двумя
  `inline`-модулями — пробел.
- Реестр модулей — `MODULES` в settings.js: `{id, file, inline?, desc}`; зоны по умолчанию — `DEFAULT_LAYOUT`.

| id | файл | что показывает / клики |
|---|---|---|
| user | User | `user@host`, стиль `shell.bar.prompt` |
| workspaces | Workspaces | `~/ws/{1,[2]}` — столы этого монитора с окнами + активный; клик (колёсико — вся панель) |
| jobs | Jobs | `[N]` окон на активном столе |
| command | Command | `❯ app  # title` активного окна, эффект набора; ❯ красный при urgent |
| media | Media | MPRIS: клик пауза, правый next, средний prev |
| tray | Tray | `[‹ 󰙯 󰓓]` значками (`S.trayGlyph` по `S.TRAY_ICONS`, иначе первая буква) или названиями (`shell.bar.trayStyle`), сворачивается в `[+N]`; правый клик — TrayMenu (свой DBusMenu) |
| cpu / mem | Cpu / Mem | загрузка (+ спарклайн) / память; клик — ProcsPopup (ps, [kill]) |
| gpu / temp | Gpu / Temp | amdgpu busy+temp / k10temp·coretemp·zenpower; без датчика скрыты |
| netspeed | NetSpeed | ↓↑ по всем интерфейсам кроме lo |
| net | Net | eth / wifi ssid % / offline (Quickshell.Networking); клик — nmtui |
| vol | Vol | Pipewire; колёсико ±5% (`scrollable`), клик — MixerPopup, правый — mute |
| bat | Bat | UPower, только если есть батарея ноутбука |
| updates | Upd | число обновлений; клик paru -Syu, правый — проверить |
| shellupd | ShellUpd | `nopox ↑N` — новые коммиты shell; клик — ShellUpdPopup |
| notify | Notify | `log N` / `dnd`; клик — NotifyCenter, правый — DND |
| kbd | Kbd | раскладка niri; клик/колёсико (`scrollable`) — переключить |
| clock | Clock | `shell.bar.clock` по Qt.locale(); клик — CalPopup |

- Попап: `SomePopup { id: p; owner: root; bar: root.bar }` и `p.toggle()`. `TuiPopup` сам
  позиционируется у `owner`, закрывается кликом мимо (`grabFocus`), учитывается в `bar.openPopups`
  (держит автоскрываемую панель открытой). Содержимое — дочерние элементы (ColumnLayout внутри).
- `rec` (Rec) — `● REC мм:сс` только во время записи, клик — стоп; `home` (Home) — `≡`, открывает меню home
  (по умолчанию выключен: меню открывает клик по `user`).

### 4.4b Раскладки (`LAYOUTS` в settings.js)

Модули панели и секции home — одна механика: `LAYOUTS[key] = {items, zones, def, labels, hint}`
(`shell.bar.layout`: зоны left/center/right/off; `shell.home.layout`: on/off). `normalizeLayout(l, key)`,
`moveModule(l, id, d, key)`, `reorderModule(l, id, d, key)`, `zoneOf(l, id, key)`, `layoutRows(key, layout)`;
без `key` — панель. Элемент, которого нет в сохранённой раскладке (вышел с обновлением), встаёт в свою зону по умолчанию
**после соседа** из `def` (`rec` — сразу за `media`), а не в конец. Новая раскладка — запись в `LAYOUTS`, строки
`layoutRows(key, …)` в `sections()`, умолчание отдаёт `defaultOf`.

### 4.4c Меню home (`HomePanel.qml`, `home/`, `services/Home.qml`)

- Открывают клик по `user` на панели (`Home.toggle(bar.screen.name)` — на мониторе этой панели), `Mod+A`,
  `qs ipc call home toggle`. Окно — `PanelWindow` на весь экран, кроме места панели (`barSpace`: панель остаётся
  кликабельной, клик по `user` закрывает меню), клик мимо колонки закрывает. Колонка выезжает от края
  (`shell.home.side`), ширина в символах — `shell.home.width`.
- Секции — `home/<file>.qml` из `HOME_SECTIONS` по `shell.home.layout.on`, грузятся `Loader.setSource(url, {panel})`.
  **Контракт секции** (`home/Section.qml`): `title`, `available` (false — секции не видно: нет устройства),
  `count` — элементов под фокус (0 — только смотреть), `cur`, `focused`, `isCur(i)` для выделения,
  `key(event)` → true, если обработала (←→ обычно двигают `cur` или значение), `activate(i)` — ↵ / Space / клик,
  `pick(i)` — клик мышью ставит фокус. Панель двигает ↑↓ между элементами и секциями, Tab — по секциям, Esc — закрыть.
  Ширина символа для отступов — `panel.cell`.
- Данные — из сервисов (Weather, NightLight, Recorder, Brightness, Notifs, Sys) и модулей Quickshell
  (Networking, Bluetooth, Mpris, UPower/PowerProfiles, Pipewire). Секции Wi-Fi и bluetooth, пока открыты, включают
  поиск (`scannerEnabled`, `discovering`) и выключают при закрытии. Пароль новой сети — поле под ней, `connectWithPsk`.
- Опасные действия (выход, перезагрузка, выключение) — двойное нажатие, «точно? ↵».
- OSD (`OsdWindow.qml`) молчит, пока меню открыто: там свои ползунки.

### 4.4a Скриншоты (`ShotWindow.qml`)

- Окно на **каждый** экран (Variants в LazyLoader): `ScreencopyView { live: false }` ловит один кадр при создании.
  Пока `hasContent` нет, ничего своего не рисуем — иначе затемнение попадёт в кадр. Режим `window` вместо кадра
  показывает картинку (`openImage`): снимок окна (`niri msg --json pick-window` → `screenshot-window --id --path`, файл
  niri пишет в фоне — ждём его) или любой файл (`shot edit`).
- Разметка `anns` — в координатах экрана `target`, область `sel` только обрезает (ручки меняют её, не двигая рисунок).
  Фигуры — один `Canvas` размером с область; шаги и текст — элементы; размытие (`MultiEffect`) и пиксели
  (`ShaderEffectSource` с крошечным `textureSize` и `smooth: false`) — по `base`, то есть по чистому кадру.
- Экспорт — `crop.grabToImage(cb, sel × factor)` (factor — пикселей кадра на логический пиксель), файл в
  `$XDG_RUNTIME_DIR/nopox-shot/shot.png` (папка создаётся при открытии: `saveToFile` в несуществующую молча падает),
  дальше `wl-copy` / копия в `shell.shot.dir` и уведомление — через `execDetached`, окно закрывается сразу.
- Клавиши инструментов — по скан-коду (`letter()`): в ru-раскладке `event.key` для R — «К». Enter, закончивший ввод текста,
  экспорт не запускает (`textClosedAt`). `Mod+Shift+S`/`Print` — в `binds.kdl`; в эталонном `config.kdl` niri остались `Ctrl/Alt+Print`.
- Настройки `shell.shot.*`: `dir`, `enter` (copy/save/both), `notify`, а `tool`/`color`/`width` — последние выбранные.

### 4.5 Полноэкранные окна (Launcher, WallPicker, Settings, Displays, Binds, lock preview)

Единый шаблон — копировать его для новых окон:

```qml
Scope {
    property bool open: false
    IpcHandler { target: "name"; function toggle(): void { root.open = !root.open; } }
    LazyLoader {
        active: root.open
        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "nopox-<name>"
            MouseArea { anchors.fill: parent; onClicked: root.open = false }   // клик мимо — закрыть
            Rectangle { /* box: bg, border accent 2px, ширина в символах cell.advanceWidth * N */
                MouseArea { anchors.fill: parent }                          // глотает клики внутри
                // заголовок на линии рамки: Rectangle y:-height/2 с T "[ ~/путь/ ]"
                // ...содержимое; внизу строка подсказок: [["↵","действие"], …] акцентом
            }
        }
    }
}
```

Флаг открытия хранится по-разному: `Settings.open`, `Wallpaper.pickerOpen`, `root.open` у остальных.
Навигация везде одинакова: ↑↓ / j k (в полях ввода — Ctrl+J/K), ←→ / h l, ↵, Esc/q, Tab — разделы.
Выделение строки — `▌ ` акцентом и фон `Theme.bg1`; изменённое значение — ` *`.
Наведение мыши выделяет строку только при реальном сдвиге курсора (`lastMouse`).

**Launcher**: меню — только действия, всё настраиваемое — в окне настроек (`setup` открывает его).
Корень: `apps/`, `wallpaper`, `setup`, `packages/` (install, aur, remove, update), `system/` (lock, suspend,
logout, reboot, poweroff), `about` (`about()`: fastfetch с `extras/fastfetch/config.jsonc` из shell,
акцент — truecolor `--logo-color-1/2`, окно закрывается по Enter). Узел дерева `{label, desc, icon, children | provider | run}`. Провайдеры:
`apps` (DesktopEntries), `repo` (`pacman -Sl`), `installed` (`pacman -Qe`), `aur` (одна строка `paru <запрос>`).
`repo`/`installed` кешируются до следующего открытия. Разделы показываются как каталоги (синие, со `/`).
Если меню открыто сразу в разделе (`launcher apps`), этот уровень — нижняя граница (`win.base`):
Esc/Backspace/← на нём закрывают окно, а не поднимаются в корень.

**DisplaysWindow**: любое изменение → `begin()` снимает снимок `niri.out.*`, 15 с на `y`;
иначе (или `n`/Esc) `revert()` через `replacePrefix`. Последний включённый монитор выключить нельзя.
Расположение `place` пересчитывается в `x/y` (`recomputePlacements`): обе координаты пишутся всегда (`pin`) —
в `displays.kdl` попадает только заданное, и монитор с одной координатой niri ставил по-своему. Опора тоже
получает явные координаты; встречная ссылка («A слева от B» при «B справа от A») сбрасывает `place` у опоры.

### 4.6 Уведомления

`Notifs` — `NotificationServer` (actions, body, persistence; без картинок и разметки — тело чистится
`clean()`). Запись: `{key, time, app, summary, body, urgency, actions, notif}`; `history` (до 100),
`entries[key]`, попапы — `ListModel` только с ключами (карточки не пересоздаются). Уровни:
Critical → ERROR (красный), Low → DEBUG (серый), иначе INFO (акцент). DND пропускает только critical.
`centerOpen` скрывает попапы, пока открыта история. Уведомления с hint `transient` — только попап, без истории и `unread`
(так шлёт `MuteNotify`: `notify-send -p … -h boolean:transient:true`, прошлое своё закрывает по id через `CloseNotification`;
смена устройства по умолчанию мьютом не считается).

**Steam** — уведомления приходят от отдельного плагина Millennium [nopox-notify](https://github.com/nopoxxx/nopox-notify)
(свой репозиторий): он забирает тосты из `NotificationStore` Steam до показа и шлёт их через `notify-send -a Steam`,
со стороны shell это обычные уведомления. Устройство, отладка и журнал (`~/.cache/nopox-notify.log`) — в его README.

### 4.7 Блокировка и greeter

- `LockScreen`: `WlSessionLock` + `PamContext` (config `login`, user `Sys.user`). При падении quickshell
  сессия остаётся заблокированной — это поведение протокола. `IdleMonitor` по `shell.lock.idle` (мин).
- `LoginPrompt` ничего не проверяет: отдаёт сигналы `submit(password)`, `userChosen`, `power`, `cancel`.
  `askUser: true` — greeter (сначала имя, Tab — сессия, F11/F12 — reboot/poweroff).
- Greeter: `extras/install-greeter.sh` копирует shell (без `.git`, `extras`, `docs`, `README.md`, `AGENTS.md`,
  `CLAUDE.md`) в `/usr/share/nopox-shell`; greetd запускает `niri -c /etc/greetd/nopox-niri.kdl`, тот — `qs -p …/greeter.qml`.
  Greeter работает под пользователем `greeter`, домашние папки не видит — поэтому `GreeterSync`
  из сессии пользователя копирует `settings.json`, обои и `wallpaper-fill` в `/var/lib/nopox-greeter/$USER/`.
  Последний пользователь и сессия — `/var/lib/nopox-greeter/.greeter/last`.
  **После изменений в QML greeter надо переустановить** (`Mod+S → system/ → обновить greeter` или `sudo extras/install-greeter.sh`).

### 4.8 Обновления

- `ShellUpdate`: через минуту после старта и раз в `shell.update.hours` — `git fetch` в
  `Quickshell.shellDir`, список `HEAD..@{u}`; `update()` — `git pull --ff-only` и перезапуск через
  отвязанный `sh` (`pkill -x qs; niri msg action spawn -- qs`), уведомление шлёт уже новый shell.
- `Updates`: `checkupdates` + `paru -Qua` раз в час; `run()` — `paru -Syu` в окне `nopox-term`.

## 5. Хранение данных

| Путь | Что | Кто пишет |
|---|---|---|
| `~/.config/nopox/settings.json` | настройки, только отличия от умолчаний | Settings, install.sh (`set_setting`) |
| `~/.config/niri/nopox/*.kdl` | сгенерированный конфиг niri | Settings, Binds (keys.kdl) |
| `~/.config/gtk-{3,4}.0/nopox.css`, `@import` в `gtk.css` | палитра GTK | AppTheme |
| `~/.config/qt6ct/qt6ct.conf`, `qt6ct/colors/nopox.conf` | палитра и шрифт Qt | AppTheme |
| gsettings `org.gnome.desktop.interface` | тёмная схема, adw-gtk3-dark, иконки, акцент, шрифт, курсор | AppTheme |
| `~/.local/state/nopox/wallpaper`, `wallpaper-fill` | текущие обои и режим | Wallpaper |
| `~/Pictures/Wallpapers/` | коллекция, загрузки wallhaven как `wallhaven-<id>.<ext>` | Wallpaper |
| `/var/lib/nopox-greeter/<user>/` | копия для greeter | GreeterSync |
| `/var/lib/nopox-greeter/.greeter/last` | последний пользователь и сессия | greeter.qml |
| `/usr/share/nopox-shell/` | копия shell для greeter | install-greeter.sh |
| `~/.cache/cliphist/db` | история буфера | cliphist (через Clipboard) |
| `~/Videos/Screencasts/` (`shell.rec.dir`) | записи экрана `rec_<дата>.mp4` | Recorder |
| `$XDG_RUNTIME_DIR/nopox-clip/` | картинки из истории для предпросмотра | ClipboardWindow |

## 6. IPC (`qs ipc call <target> <fn>`)

| target | функции | где |
|---|---|---|
| `launcher` | `toggle`, `apps`, `open`, `close` (не `show` — занято `qs ipc show`) | Launcher.qml |
| `wallpaper` | `picker`, `set <path>`, `fill <fill\|fit\|stretch>` | WallPicker.qml |
| `settings` | `toggle`, `open <раздел>` (`""` — последний открытый) | SettingsWindow.qml |
| `displays` | `toggle` | DisplaysWindow.qml |
| `binds` | `toggle` | BindsWindow.qml |
| `lock` | `lock`, `locked`, `preview` | LockScreen.qml |
| `notify` | `dnd`, `clear` | services/Notifs.qml |
| `shot` | `region`, `window`, `edit <путь>` | ShotWindow.qml |
| `clipboard` | `toggle` | ClipboardWindow.qml |
| `home` | `toggle`, `open`, `close` | services/Home.qml |
| `record` | `toggle`, `region`, `screen`, `stop` | services/Recorder.qml |

Новые IPC-функции нужно объявлять с типами (`function x(): void`, аргументы `name: string`).

## 7. Рецепты

**Новая настройка.** Добавить строку в нужный раздел `sections()` (`key`, `label`, `type`, `def`,
`hint`, ограничения). Читать через `Settings.get("…")` — привязки обновятся сами. Если влияет на niri —
использовать в `niriFiles()` и дописать ключ в `niriFileOf()`. Действие — `act("имя", "подпись", "подсказка")`
и `case` в `SettingsWindow.runAction()`; если оно открывает окно — добавить имя в список `returnHere`.

**Новый модуль панели.** `bar/Name.qml` (обычно `Seg { … }` с `import qs`, `qs.bar`, `qs.services`)
со свойствами `bar` и `available`; запись в `MODULES` (`id`, `file: "Name"`, `desc`, `inline` при
необходимости); при желании — в `DEFAULT_LAYOUT` (иначе появится в «выключены»). Данные — из сервиса
в `services/`, а не опросом в каждом модуле (модулей по экземпляру на монитор). Обновить таблицы в
этом файле и список модулей в документации (`docs/index.html`, раздел bar).

**Новая секция меню home.** `home/Name.qml` на `Section { title; count; … }` (контракт — §4.4c), запись в
`HOME_SECTIONS` и, если нужна по умолчанию, в `DEFAULT_HOME.on`; данные — из сервиса. Обновить список секций
в документации (`docs/index.html`, раздел home).

**Новый попап.** `bar/NamePopup.qml` на `TuiPopup { title: "…" }`, внутри — `T`, `RowLayout`,
`Repeater`; кликабельные элементы — `[текст]` с `MouseArea` и `Qt.PointingHandCursor`.

**Пункт меню.** Только для действий (настройки — в окно настроек). Узел в `Launcher.menu`; для команды
в терминале — `term("cmd", hold)` (плавающее окно `nopox-term`), для фоновой — `spawn([...])`.

**Новое окно.** Шаблон из §4.5, экземпляр — в `shell.qml`, IPC-команда, пресет в `BindsWindow.presets`,
при необходимости — бинд в `binds.kdl` внутри `niriFiles()`, строка-действие в настройках (с возвратом через
`Settings.back()`) или пункт в меню. Заголовок — путь, откуда окно открывается: `[ ~/settings/system/displays/ ]`.

**Новый сервис.** `services/Name.qml` с `pragma Singleton` и `Singleton { }`. Синглтон создаётся при первом
обращении: если он должен работать без UI — сослаться на него в `shell.qml` (как `_shellUpdate`, `_binds`, `_appTheme`, `_defaultApps`, `_muteNotify`, `_clipboard`, `_home`, `_night`, `_recorder`).

## 8. Соглашения кода

- Отступ 4 пробела; `id: root` у корня; `readonly property` для производных значений; привязки
  вместо императивных обновлений. Изменение объектов/массивов — только новой копией
  (`Object.assign({}, …)`, `concat`, `map`), иначе привязки не увидят изменения.
- Комментарии короткие, по-русски, объясняют «почему». Шапка файла — что это и IPC/клавиши.
- Текст — только через `T`; цвета — только `Theme.*` (акцент — `Theme.accent`); моноширинная сетка:
  ширины в символах через `TextMetrics { text: "M" }` → `cell.advanceWidth * N`.
- Разметка цветом — `textFormat: Text.StyledText` и хелпер `c(color, s)`; пользовательский текст экранировать.
- Внешние команды: `Quickshell.execDetached([...])` или `Process`; для shell —
  `["sh", "-c", 'скрипт с "$1"', "sh", arg1, …]` — **никогда не подставлять данные в текст скрипта**.
  В Launcher для строк — `shq()`.
- Терминальные окна — только через `Term` / `S.termCmd` (учитывает kitty/alacritty/ghostty/foot и класс окна).
- Уведомления от shell — `notify-send -a nopox-shell "Заголовок" "Текст"`.
- Стиль UI: рамка 2px акцентом, заголовок `[ ~/путь/ ]` на линии рамки, разделители `── текст ───`,
  каталоги синие со `/`, кнопки `[текст]`, курсор `█`, эффект «печати» по символу (интервал 14 мс).

## 9. Подводные камни

- `Settings.set` сравнивает с умолчанием через `===` — для объектов (layout, keys) ключ всегда пишется.
- Не писать файлы `nopox/*.kdl` часто: niri перечитывает конфиг на каждую запись (отсюда задержки и кэш `_written`).
- Глифы Nerd Font вне BMP — два UTF-16 знака: длину и срез для анимации печати считать через `Array.from`.
  В `Terminess Nerd Font Mono` значки ужаты в клетку и не читаются — Tray рисует их обычным `Terminess Nerd Font`.
  Новый глиф в `TRAY_ICONS` проверять по шрифту (fontTools, имена вида `md-discord`); в иконке элемента трея
  смотреть только `image://icon/<имя>` — в URL pixmap-иконок путь DBus (`/org/chromium/…` у любого Electron).
- Приложения, запущенные из shell, наследуют окружение процесса `qs`, а не текущий `environment` из niri. Для тем это
  закрыто `Settings.appEnv()` (меню, `Term`); новая переменная в `misc.kdl` — добавить в `S.APP_ENV`, иначе до программ
  из shell она дойдёт только после перезапуска shell. Уже запущенные программы окружение не меняют — их надо перезапустить.
- Одинаковое сочетание в `nopox/binds.kdl` и в `config.kdl` niri принимает молча, побеждает подключённое позже —
  `config.kdl`. Бинд nopox, занятый в старом эталоне (`Mod+Shift+V` был `switch-focus-between-floating-and-tiling`,
  теперь `Mod+Ctrl+V`), у таких пользователей не сработает, пока строку не убрать из их `config.kdl` (install.sh предлагает перенести).
- Долгий `Process` нельзя перезапустить в том же такте (`running = false; running = true` — Quickshell может
  пропустить): остановить и запустить таймером (NightLight). Короткие запросы, ответ которых может опоздать, — свой
  процесс на запрос (`Component.createObject`, ClipboardWindow).
- Дети `qs` при его выходе по сигналу не умирают: долгоживущие процессы (wl-paste, gammastep) при старте сначала гасят
  прежние (`pkill -u … -x(f)`), иначе каждый перезапуск shell их удваивает.
- sysfs (`/sys/class/backlight/*/brightness`) не шлёт inotify — яркость опрашивается (Brightness, 400 мс).
- MPRIS не присылает позицию сам: пока играет, `player.positionChanged()` раз в секунду (home/Media).
- `gammastep -O` под Wayland не выходит, а держит цвет, пока жив: ночной режим = запущенный процесс.
- `wf-recorder` дописывает файл только по SIGINT (`Process.signal(2)`); kill оставит битый mp4.
- `normalizeLayout` хранит `off` явно: модуль, которого нет ни в одной зоне, считается новым.
- Repeater отдаёт копии объектов — сравнивать по `name`/`id`, а не `===` (см. DisplaysWindow).
- `Niri.windows` — объект по id; `Niri.workspaces` отсортированы по `idx`; номер стола относится к монитору.
  `niri msg action focus-monitor` **переносит курсор в центр монитора** — вызывать его только для другого
  монитора (`Niri.focusWorkspaceOn`), иначе курсор уходит с панели и следующая прокрутка попадает в окно.
- Qt шлёт hover, когда список прокручивается под неподвижным курсором, — см. `lastMouse`.
- `Qt.formatDate` игнорирует локаль — использовать `Qt.locale().toString(date, fmt)`.
- Нативное меню трея (`display()`) не используется: нужен QApplication и оно не в стиле — свой `TrayMenu`.
- ghostty принимает класс окна только с точкой: `nopox-term` → `dev.nopox.term` (`S.termClass`).
- В greeter нет `$HOME` пользователя: всё, что нужно greeter'у, должно идти через GreeterSync.
- Бинды из `config.kdl` парсятся построчно: многострочные бинды в окне биндов не видны.
- `paru-bin` из AUR — готовый бинарник под конкретную `libalpm.so.N`; после обновления pacman он перестаёт
  запускаться (так было с pacman 7.1 / libalpm.so.16). Проверять `paru --version`, а не `command -v paru`;
  shell (`Updates`, меню packages/) при неработающем paru молча показывает 0 обновлений.

## 10. Установщик `install.sh`

Bash, `set -euo pipefail`, запуск от обычного пользователя. Порядок: проверки → выбор (`choose`:
терминал, оболочка, браузер, файловый менеджер, программы из `APP_CATALOG` `группа|id|описание|пакеты|умолч.`,
мод Discord) → итог и подтверждение → пакеты pacman (`PKGS`; bluez — только если есть адаптер, в конце `systemctl enable --now bluetooth`) → **niri ≥ `NIRI_MIN` (25.11)**: настраиваемые горячие
углы и `screenshot-window --path` появились в 25.11, старый niri конфиг nopox не примет, а `pacman -S --needed` его не
обновит — предлагает `pacman -Syu`, иначе выход → **chaotic-aur** (ключ `3056513887B78AEB`, keyring и mirrorlist с
`cdn-mirror.chaotic.cx`, запись в `pacman.conf` с бэкапом; уже подключён — пропуск, `--no-chaotic` — без него) →
программы и иконки `gruvbox-plus-icon-theme` через **`install_pkgs`**: что есть в репозиториях (официальные, chaotic-aur,
CachyOS) — одним `pacman -S`, чего нет нигде — `build_aur` (`makepkg`); «`a/b`» в списке — варианты имени (первый из
репозиториев, иначе последний, обычно `-bin`), «стоит ли» — `pacman -T` (учитывает provides); не поставилось — честный
список и команда повтора; для Steam Vulkan-драйвер ставится явно в той же транзакции (`vulkan_drivers` по PCI vendor из
`/sys/class/drm/card*/device/vendor`: AMD → `vulkan-radeon`, Intel → `vulkan-intel`, NVIDIA → `nvidia-utils` только при модуле
nvidia (он отключает nouveau), иначе `vulkan-nouveau`; ни одной известной карты (VM) → `vulkan-swrast`; всё с `lib32-`),
иначе с `--noconfirm` pacman молча берёт первого поставщика — `nvidia-utils` →
**paru только для shell** (обновления AUR, меню packages/): из репозитория или `paru-bin`
через `makepkg`, не запустился — предупреждение; **сам установщик paru не пользуется** →
клон/обновление в `~/.config/quickshell` → `set_setting shell.terminal/files/sh/browser` →
конфиг niri (замена или дописать два include; если nopox уже подключён — предлагает закомментировать
встроенный `Mod+Shift+S`/`Print { screenshot; }` старого эталона: он перекрыл бы скриншот nopox, и перенести
`Mod+Shift+V { switch-focus-between-floating-and-tiling; }` на `Mod+Ctrl+V` — иначе не откроется история буфера; затем `niri validate`,
при ошибке — откат; стартовые `nopox/*.kdl` — вывод генератора с настройками по умолчанию, пересобирать при его изменении) → конфиг
терминала → конфиг fastfetch (если своего нет) → оболочка → приложения по умолчанию (`desktop_of <пакет> <mime>`: тот
`.desktop`, у которого есть нужный MimeType, — у thunar первым по алфавиту идёт `thunar-bulk-rename.desktop`) → Discord →
**Steam: уведомления** (если стоит steam, флаг `--no-steam-notify` пропускает): `install_pkgs millennium bun`, симлинки
`libXtst.so.6` → bootstrap Millennium (пакет ставит их сам, только если Steam уже запускался), клон
`~/.local/share/nopox-notify`, `bun run build`, включение в `~/.config/millennium/config.json` → `plugins.enabledPlugins`
(правка JSON через `bun -e`, битый файл не трогается) → greeter → итог.
Всё заменяемое уходит в `*.bak-<дата>`. С `--yes` вопросов нет и pacman/paru получают `--noconfirm`.
Флаги описаны в шапке файла и в документации (`docs/index.html`, раздел install) — менять синхронно.
