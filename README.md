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
- **Меню** (`Mod+D`) в духе omarchy — для действий: `apps/`, `wallpaper`, `setup` (открывает настройки),
  `packages/` (install, aur, remove, update), `system/` (lock, suspend, logout, reboot, poweroff), `about`.
  Нечёткий поиск, установка пакетов из репозиториев и AUR через paru.
- **Обои** (`Mod+Shift+W`): локальная коллекция и поиск на wallhaven.cc, режимы fill / fit / stretch.
- **Мониторы** (`Mod+S → system/ → мониторы`): карта расположения, режим, масштаб, поворот, расположение относительно
  других, VRR, основной монитор. Изменения ждут подтверждения 15 секунд и иначе откатываются.
- **Бинды** (`Mod+S → input/ → бинды`): все сочетания niri и nopox с поиском — изменить, добавить,
  отключить, вернуть. Сочетание можно нажать или ввести текстом; перед применением — `niri validate`.
- **Настройки** (`Mod+S`, `setup` в меню) в стиле menuconfig, разделы по назначению:
  `look/` (акцент, шрифт, темы приложений, обои), `windows/` (отступы, рамки, тени, анимации),
  `input/` (клавиатура, мышь, курсор, бинды), `bar/` (модули и панель), `notify/`, `lock/`,
  `system/` (мониторы, сеть, звук, терминал, конфиги, обновления shell). `/` — поиск по всем настройкам.
  Изменения применяются сразу; окна, открытые из настроек, по `Esc` возвращают в них.
- **Темы приложений** (`Mod+S → look/ → темы Qt и GTK`): GTK- и Qt-приложения в той же палитре Gruvbox,
  с тем же акцентом и шрифтом, что и shell, и иконками Gruvbox Plus — через adw-gtk3/libadwaita и qt6ct. Уже открытые окна
  подхватывают изменения после перезапуска приложения.

## Установка

На Arch Linux и производных (CachyOS, EndeavourOS, …), от обычного пользователя:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/nopox-shell/main/install.sh)
```

Установщик сначала спрашивает, что ставить, показывает итог и только потом устанавливает:

- **терминал** — kitty, alacritty, ghostty или foot (конфиг в Gruvbox + Terminess, `Mod+T`);
- **оболочка** — zsh (подсказки и подсветка), fish или bash; приглашение как панель: `user@host ~/путь ❯`,
  красный `❯` — если команда завершилась ошибкой;
- **браузер** — Helium, Firefox, Zen, Chromium, Brave или Vivaldi (станет браузером по умолчанию);
- **файловый менеджер** — Thunar, Nautilus, Dolphin, Nemo или yazi в терминале (`Mod+E`);
- **программы** по группам: медиа, общение, графика (в т. ч. PhotoCraft), работа и код, игры, утилиты;
- **Discord** — как есть, с Vencord, с BetterDiscord или Vesktop вместо него.

Дальше — пакеты (программы через `paru`: из репозиториев или AUR), клон shell в `~/.config/quickshell`,
конфиг niri (или два `include` к вашему) и, по желанию, greeter. Всё, что заменяется, остаётся рядом как `*.bak-<дата>`.

| Флаг | Что делает |
|---|---|
| `--yes` | без вопросов, всё по умолчанию |
| `--terminal`, `--shell`, `--browser`, `--files` | выбор без вопроса, например `--terminal foot` |
| `--apps mpv,discord,steam` | программы (`none` — никаких) |
| `--discord-mod vencord` | `none`, `vencord`, `betterdiscord`, `vesktop` |
| `--keep-niri-config` | не заменять ваш `config.kdl`, только дописать `include` |
| `--no-greeter` | не ставить greeter |
| `--branch <ветка>` | другая ветка репозитория |

<details>
<summary>Вручную</summary>

```sh
sudo pacman -S --needed niri quickshell xwayland-satellite kitty git networkmanager pipewire \
    pipewire-pulse wireplumber upower pacman-contrib libnotify polkit-gnome ttf-terminus-nerd paru \
    qt6ct adw-gtk-theme xdg-desktop-portal-gnome
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
отдельно — `[обновить greeter]` или `Mod+S → system/ → обновить greeter` (нужен sudo).

## Где что хранится

| Путь | Что |
|---|---|
| `~/.config/nopox/settings.json` | настройки — только отличия от умолчаний |
| `~/.config/niri/nopox/` | настройки niri по файлу на раздел: `input`, `displays`, `layout`, `window-rules`, `cursor`, `animations`, `misc`, `binds` — генерирует shell, вручную не править |
| `~/.config/niri/nopox/keys.kdl` | свои бинды из окна биндов, подключён в `config.kdl` последним |
| `~/.config/gtk-3.0/nopox.css`, `gtk-4.0/nopox.css` | палитра для GTK — подключается первой строкой `gtk.css`, свои стили пишите после неё |
| `~/.config/qt6ct/` | палитра и шрифт для Qt (`QT_QPA_PLATFORMTHEME=qt6ct` задаёт `nopox/misc.kdl`) |
| `~/.local/state/nopox/wallpaper`, `wallpaper-fill` | текущие обои и режим заполнения |
| `~/Pictures/Wallpapers/` | коллекция обоев, сюда же скачивается с wallhaven |
| `/var/lib/nopox-greeter/<user>/` | копия настроек и обоев для greeter |
| `/var/lib/nopox-greeter/.greeter/last` | последний пользователь и сессия в greeter |

## IPC

```sh
qs ipc call launcher toggle     # меню; launcher apps — сразу программы
qs ipc call wallpaper picker    # выбор обоев; wallpaper set <путь>, wallpaper fill <fill|fit|stretch>
qs ipc call settings toggle     # настройки; settings open <раздел> — сразу раздел (look, input, system, …)
qs ipc call displays toggle     # мониторы
qs ipc call binds toggle        # бинды
qs ipc call lock lock           # блокировка; lock preview — предпросмотр без проверки пароля
qs ipc call notify dnd          # «не беспокоить»; notify clear — очистить историю
```
