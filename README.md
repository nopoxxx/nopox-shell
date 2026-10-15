# nopox-shell

Оболочка для [niri](https://github.com/YaLTeR/niri) на [Quickshell](https://quickshell.org) в стиле терминала:
панель — строка shell, меню — fzf, настройки — menuconfig. Палитра Gruvbox, шрифт Terminess (Terminus).

```
nopox@nopox-os ~/ws/{1,[2]} [1] ❯ kitty  # ~          [‹ discord] · cpu ▂▃▅▇ 4% · mem 1.7G · net eth · vol 40% · en · 21:58
```

## Что есть

- **Панель** из 17 модулей, которые расставляются по зонам left / center / right:
  `user`, `workspaces`, `jobs`, `command`, `media`, `tray`, `cpu`, `mem`, `gpu`, `temp`,
  `netspeed`, `net`, `vol`, `bat`, `updates`, `kbd`, `clock`.
  По клику — TUI-попапы: календарь как `cal`, процессы как `ps`, микшер, меню трея.
- **Меню** (`Mod+D`) в духе omarchy: `apps/`, `setup/`, `style/`, `install/`, `remove/`, `update`, `system/`.
  Нечёткий поиск, установка пакетов из репозиториев и AUR через paru.
- **Обои** (`Mod+Shift+W`): локальная коллекция и поиск на wallhaven.cc, режимы fill / fit / stretch.
- **Мониторы** (`setup/ → displays`): карта расположения, режим, масштаб, поворот, расположение относительно
  других, VRR, основной монитор. Изменения ждут подтверждения 15 секунд и иначе откатываются.
- **Бинды** (`Mod+S → бинды`, `setup/ → binds`): все сочетания niri и nopox с поиском — изменить, добавить,
  отключить, вернуть. Сочетание можно нажать или ввести текстом; перед применением — `niri validate`.
- **Настройки** (`Mod+S`): niri (клавиатура, мышь, окна, курсор, анимации),
  shell, раскладка панели. Изменения применяются сразу.

## Установка

На Arch Linux и производных (CachyOS, EndeavourOS, …), от обычного пользователя:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/nopox-shell/main/install.sh)
```

Установщик ставит пакеты (и `paru`, если его нет), клонирует shell в `~/.config/quickshell`,
ставит конфиг niri (или дописывает к вашему два `include`), по желанию — kitty в Gruvbox и greeter.
Всё, что заменяется, остаётся рядом как `*.bak-<дата>`.

| Флаг | Что делает |
|---|---|
| `--yes` | без вопросов, всё по умолчанию |
| `--keep-niri-config` | не заменять ваш `config.kdl`, только дописать `include` |
| `--no-greeter` | не ставить greeter |
| `--branch <ветка>` | другая ветка репозитория |

<details>
<summary>Вручную</summary>

```sh
sudo pacman -S --needed niri quickshell xwayland-satellite kitty git networkmanager pipewire \
    pipewire-pulse wireplumber upower pacman-contrib libnotify polkit-gnome ttf-terminus-nerd paru
git clone https://github.com/nopoxxx/nopox-shell ~/.config/quickshell
```

Затем подключите shell к niri — см. [`extras/niri.kdl`](extras/niri.kdl).
</details>

## Блокировка экрана и greeter

Блокировка (`Super+Alt+L`, `system/ → lock`, после бездействия) и greeter для greetd — один и тот же экран
в духе getty: часы как `tty-clock`, `login:` / `Password:`. Блокировка проверяет пароль через PAM,
greeter — через greetd; в greeter сначала вводится имя (подставлено последнее), `Tab` — сессия,
`F11` / `F12` — перезагрузка / выключение.

```sh
sudo ./extras/install-greeter.sh   # shell → /usr/share/nopox-shell, niri для greeter, [default_session] в greetd
sudo systemctl restart greetd
```

Greeter работает под пользователем `greeter` и не видит домашнюю папку, поэтому сессия пользователя
копирует настройки, обои и режим заполнения в `/var/lib/nopox-greeter/<user>/` — greeter выглядит так же,
как shell последнего вошедшего пользователя. После обновления shell установку нужно повторить.

## Обновления

Если shell установлен через `git clone`, он сам раз в несколько часов делает `git fetch`.
Когда в репозитории появились новые коммиты, на панели появляется `nopox ↑N`: клик — список коммитов
и `[обновить]` (`git pull --ff-only` и перезапуск shell). Greeter после этого переустанавливается
отдельно — `[обновить greeter]` или `setup/ → greeter update` (нужен sudo).

## Где что хранится

| Путь | Что |
|---|---|
| `~/.config/nopox/settings.json` | настройки — только отличия от умолчаний |
| `~/.config/niri/nopox.kdl` | сгенерирован из настроек, не редактировать вручную |
| `~/.config/niri/nopox-keys.kdl` | свои бинды из окна биндов, подключён в `config.kdl` последним |
| `~/.config/niri/nopox-binds.kdl` | ссылка на клавиши и правила nopox из клона shell |
| `~/.local/state/nopox/wallpaper`, `wallpaper-fill` | текущие обои и режим заполнения |
| `~/Pictures/Wallpapers/` | коллекция обоев, сюда же скачивается с wallhaven |
| `/var/lib/nopox-greeter/<user>/` | копия настроек и обоев для greeter |
| `/var/lib/nopox-greeter/.greeter/last` | последний пользователь и сессия в greeter |

## IPC

```sh
qs ipc call launcher toggle     # меню; launcher apps — сразу программы
qs ipc call wallpaper picker    # выбор обоев; wallpaper set <путь>, wallpaper fill <fill|fit|stretch>
qs ipc call settings toggle     # настройки
qs ipc call displays toggle     # мониторы
qs ipc call binds toggle        # бинды
qs ipc call lock lock           # блокировка; lock preview — предпросмотр без проверки пароля
qs ipc call notify dnd          # «не беспокоить»; notify clear — очистить историю
```
