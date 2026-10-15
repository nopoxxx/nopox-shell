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
- **Настройки** (`Mod+S`): niri (клавиатура, мышь, окна, курсор, анимации, масштаб экранов),
  shell, раскладка панели. Изменения применяются сразу.

## Зависимости

```
niri quickshell kitty paru pacman-contrib networkmanager pipewire wireplumber upower
ttf-terminus-nerd curl
```

`paru` — для `install/` и модуля `updates`, `pacman-contrib` — для `checkupdates`.

## Установка

```sh
git clone https://github.com/nopoxxx/nopox-shell ~/.config/quickshell
```

Затем подключите shell к niri — см. [`extras/niri.kdl`](extras/niri.kdl): автозапуск `qs`, клавиши,
правила окон и `include "nopox.kdl"`. Файл `nopox.kdl` создаётся при первом запуске shell.

## Где что хранится

| Путь | Что |
|---|---|
| `~/.config/nopox/settings.json` | настройки — только отличия от умолчаний |
| `~/.config/niri/nopox.kdl` | сгенерирован из настроек, не редактировать вручную |
| `~/.local/state/nopox/wallpaper`, `wallpaper-fill` | текущие обои и режим заполнения |
| `~/Pictures/Wallpapers/` | коллекция обоев, сюда же скачивается с wallhaven |

## IPC

```sh
qs ipc call launcher toggle     # меню; launcher apps — сразу программы
qs ipc call wallpaper picker    # выбор обоев; wallpaper set <путь>, wallpaper fill <fill|fit|stretch>
qs ipc call settings toggle     # настройки
```
