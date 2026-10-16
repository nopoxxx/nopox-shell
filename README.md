# nopox-shell

Оболочка рабочего стола для [niri](https://github.com/YaLTeR/niri) на [Quickshell](https://quickshell.org) в стиле терминала:
панель — строка shell, меню — fzf, настройки — menuconfig. Палитра Gruvbox, шрифт Terminess.

```
nopox@nopox-os ~/ws/{1,[2]} [1] ❯ kitty  # ~        [‹ 󰙯 󰓓] · cpu ▂▃▅▇ 4% · mem 1.7G · vol 40% · ru · 21:58
```

**Документация: [nopoxxx.github.io/nopox-shell](https://nopoxxx.github.io/nopox-shell/)**

## Установка

Arch Linux и производные, от обычного пользователя:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/nopox-shell/main/install.sh)
```

Установщик спросит терминал, оболочку, браузер, файловый менеджер и программы, покажет итог и только потом поставит.
Флаги и ручная установка — в [документации](https://nopoxxx.github.io/nopox-shell/#install).

## Клавиши

| | |
|---|---|
| `Mod+D` | меню: программы, обои, пакеты, питание |
| `Mod+Space` | программы |
| `Mod+S` | настройки |
| `Mod+Return` | терминал |
| `Super+Alt+L` | блокировка |
| `Mod+Shift+/` | все клавиши niri |

## Разработка

Карта проекта, соглашения и подводные камни — [`AGENTS.md`](AGENTS.md). Исходник документации — [`docs/index.html`](docs/index.html).
