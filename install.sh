#!/usr/bin/env bash
# nopox-shell — установщик для Arch Linux и производных (CachyOS, EndeavourOS, …)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/nopox-shell/main/install.sh)
#
# Флаги (всё, что не задано флагом, установщик спросит; с --yes — возьмёт по умолчанию):
#   --yes                    не задавать вопросов
#   --terminal <t>           kitty | alacritty | ghostty | foot
#   --shell <s>              zsh | fish | bash
#   --browser <b>            helium | firefox | zen | chromium | brave | vivaldi | none
#   --files <f>              thunar | nautilus | dolphin | nemo | yazi | none
#   --apps <a,b,…>           программы (список — в начале установки), none — никаких
#   --discord-mod <m>        none | vencord | betterdiscord | vesktop
#   --no-greeter             не ставить greeter (greetd)
#   --keep-niri-config       не заменять config.kdl niri, только дописать include
#   --branch <ветка>         ветка репозитория (по умолчанию main)
#
# Ничего не удаляет: всё, что заменяется, переезжает в *.bak-<дата>.
set -euo pipefail

REPO=https://github.com/nopoxxx/nopox-shell
BRANCH=main
YES=0
GREETER=ask
KEEP_NIRI=0
TERMINAL="" SHELL_CHOICE="" BROWSER="" FILES="" APPS="" DISCORD_MOD=""
DEST="$HOME/.config/quickshell"
NIRI_DIR="$HOME/.config/niri"
STAMP=$(date +%Y%m%d-%H%M%S)

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --terminal) TERMINAL=${2:?}; shift ;;
        --shell) SHELL_CHOICE=${2:?}; shift ;;
        --browser) BROWSER=${2:?}; shift ;;
        --files) FILES=${2:?}; shift ;;
        --apps) APPS=${2:?}; shift ;;
        --discord-mod) DISCORD_MOD=${2:?}; shift ;;
        --no-greeter) GREETER=no ;;
        --keep-niri-config) KEEP_NIRI=1 ;;
        --branch) BRANCH=${2:?нужно имя ветки}; shift ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный флаг: $1" >&2; exit 1 ;;
    esac
    shift
done

# ── вывод в цветах Gruvbox ───────────────────────────────────────────
if [ -t 1 ]; then
    Y=$'\e[33m' G=$'\e[32m' R=$'\e[31m' A=$'\e[36m' D=$'\e[90m' BOLD=$'\e[1m' N=$'\e[0m'
else
    Y="" G="" R="" A="" D="" BOLD="" N=""
fi

step() { printf '\n%s❯%s %s%s%s\n' "$Y" "$N" "$BOLD" "$*" "$N"; }
info() { printf '  %s%s%s\n' "$D" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# ask "вопрос" y|n — default; с --yes сразу ответ по умолчанию
ask() {
    local q=$1 def=${2:-y} ans hint
    if [ "$YES" = 1 ]; then [ "$def" = y ]; return; fi
    hint=$([ "$def" = y ] && echo "Y/n" || echo "y/N")
    printf '  %s?%s %s [%s] ' "$A" "$N" "$q" "$hint"
    read -r ans </dev/tty || ans=""
    ans=${ans:-$def}
    [[ $ans =~ ^[YyДд] ]]
}

backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        mv "$1" "$1.bak-$STAMP"
        info "старое — в $1.bak-$STAMP"
    fi
}

# choose ПЕРЕМЕННАЯ "заголовок" умолчание "id|описание" … — нумерованный выбор одного варианта.
# Если переменная уже задана флагом — только проверяет, что такой вариант есть.
choose() {
    local var=$1 title=$2 def=$3 ans i line id
    shift 3
    local ids=()
    for line in "$@"; do ids+=("${line%%|*}"); done
    if [ -n "${!var}" ]; then
        printf '%s\n' "${ids[@]}" | grep -qx "${!var}" || die "$title: нет варианта «${!var}» (есть: ${ids[*]})"
        ok "$title: ${!var}"
        return
    fi
    if [ "$YES" = 1 ]; then
        printf -v "$var" '%s' "$def"
        ok "$title: $def"
        return
    fi
    printf '\n  %s%s%s\n' "$BOLD" "$title" "$N"
    i=1
    for line in "$@"; do
        id=${line%%|*}
        printf '   %s%2d)%s %-14s %s%s%s%s\n' "$A" "$i" "$N" "$id" "$D" "${line#*|}" "$N" \
            "$([ "$id" = "$def" ] && printf '  %s← по умолчанию%s' "$Y" "$N")"
        i=$((i + 1))
    done
    while true; do
        printf '  %s?%s номер [Enter — %s] ' "$A" "$N" "$def"
        read -r ans </dev/tty || ans=""
        if [ -z "$ans" ]; then printf -v "$var" '%s' "$def"; break; fi
        if [[ $ans =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le ${#ids[@]} ]; then
            printf -v "$var" '%s' "${ids[$((ans - 1))]}"
            break
        fi
        warn "нужен номер от 1 до ${#ids[@]}"
    done
    ok "$title: ${!var}"
}

# set_setting ключ значение — в ~/.config/nopox/settings.json (shell пишет его по ключу на строку)
set_setting() {
    local f="$HOME/.config/nopox/settings.json" k=$1 v=$2
    mkdir -p "${f%/*}"
    if [ ! -s "$f" ] || ! grep -q '"' "$f"; then
        printf '{\n  "%s": "%s"\n}\n' "$k" "$v" > "$f"
    elif grep -q "\"$k\":" "$f"; then
        sed -i "s|\"$k\": *\"[^\"]*\"|\"$k\": \"$v\"|" "$f"
    else
        sed -i "0,/{/s//{\n  \"$k\": \"$v\",/" "$f"
    fi
}

# .desktop-файл пакета — для браузера и файлового менеджера по умолчанию
desktop_of() {
    pacman -Qlq "$1" 2>/dev/null | grep -m1 '^/usr/share/applications/.*\.desktop$' | xargs -r basename
}

printf '%s' "$Y"
cat <<'EOF'

  ┌─[ nopox-shell ]──────────────────────────────────────┐
  │  terminal-style shell для niri на Quickshell          │
  └───────────────────────────────────────────────────────┘
EOF
printf '%s' "$N"

# ── проверки ─────────────────────────────────────────────────────────
step "Проверка системы"
[ "$(id -u)" -ne 0 ] || die "запускайте от обычного пользователя — sudo спросят там, где нужно"
command -v pacman >/dev/null || die "нужен Arch Linux или производный дистрибутив (pacman)"
command -v sudo >/dev/null || die "нужен sudo"
curl -fsS --max-time 15 -o /dev/null https://github.com || die "нет доступа к github.com"
ok "Arch-подобная система, $(uname -r)"

# ── выбор ────────────────────────────────────────────────────────────
step "Что ставим"

choose TERMINAL "Терминал" kitty \
    "kitty|быстрый, GPU, вкладки и картинки" \
    "alacritty|минималистичный, GPU" \
    "ghostty|новый, GPU, нативный GTK" \
    "foot|лёгкий, только Wayland"

choose SHELL_CHOICE "Оболочка" zsh \
    "zsh|подсказки по истории и подсветка команд" \
    "fish|удобный сразу, без настройки" \
    "bash|стандартный"

choose BROWSER "Браузер" helium \
    "helium|Chromium без телеметрии и лишнего" \
    "firefox|Firefox" \
    "zen|Zen — Firefox с вертикальными вкладками" \
    "chromium|Chromium" \
    "brave|Brave — со встроенным блокировщиком" \
    "vivaldi|Vivaldi — много настроек" \
    "none|не ставить"

choose FILES "Файловый менеджер" thunar \
    "thunar|лёгкий, из Xfce" \
    "nautilus|GNOME Files" \
    "dolphin|KDE, много возможностей" \
    "nemo|из Cinnamon" \
    "yazi|в терминале — в стиле shell" \
    "none|не ставить"

# группа|id|описание|пакеты|по умолчанию
APP_CATALOG=(
    "Медиа|mpv|mpv — видеоплеер|mpv|1"
    "Медиа|obs|OBS Studio — запись и стримы|obs-studio|0"
    "Медиа|spotify|Spotify|spotify-launcher|0"
    "Медиа|qbittorrent|qBittorrent|qbittorrent|0"
    "Медиа|imv|imv — просмотр картинок|imv|0"
    "Общение|discord|Discord (моды — следующий вопрос)|discord|1"
    "Общение|telegram|Telegram|telegram-desktop|1"
    "Графика|photocraft|PhotoCraft — аналог Photoshop на Rust, альфа|photocraft-bin|1"
    "Графика|gimp|GIMP|gimp|0"
    "Графика|krita|Krita — рисование|krita|0"
    "Работа и код|code|Code - OSS (VS Code)|code|0"
    "Работа и код|vscodium|VSCodium|vscodium-bin|0"
    "Работа и код|neovim|Neovim|neovim|0"
    "Работа и код|libreoffice|LibreOffice|libreoffice-fresh|0"
    "Работа и код|obsidian|Obsidian — заметки|obsidian|0"
    "Игры|steam|Steam (включит multilib)|steam|0"
    "Игры|lutris|Lutris|lutris|0"
    "Игры|heroic|Heroic — Epic Games и GOG|heroic-games-launcher-bin|0"
    "Игры|gametools|MangoHud + GameMode|mangohud gamemode|0"
    "Утилиты|btop|btop — монитор ресурсов|btop|1"
    "Утилиты|flatpak|Flatpak|flatpak|0"
    "Утилиты|timeshift|Timeshift — снимки системы|timeshift|0"
)
SEL=()
for i in "${!APP_CATALOG[@]}"; do SEL[i]=${APP_CATALOG[i]##*|}; done

app_field() { local IFS='|'; local f=(${APP_CATALOG[$1]}); printf '%s' "${f[$2]}"; }

if [ -n "$APPS" ]; then
    for i in "${!APP_CATALOG[@]}"; do SEL[i]=0; done
    for id in ${APPS//,/ }; do
        [ "$id" = none ] && continue
        found=0
        for i in "${!APP_CATALOG[@]}"; do
            [ "$(app_field "$i" 1)" = "$id" ] && { SEL[i]=1; found=1; }
        done
        [ "$found" = 1 ] || die "--apps: нет программы «$id»"
    done
elif [ "$YES" != 1 ]; then
    while true; do
        printf '\n  %sПрограммы%s %s(номера через пробел — отметить/снять, Enter — готово)%s\n' "$BOLD" "$N" "$D" "$N"
        group=""
        for i in "${!APP_CATALOG[@]}"; do
            g=$(app_field "$i" 0)
            [ "$g" != "$group" ] && { printf '   %s── %s%s\n' "$D" "$g" "$N"; group=$g; }
            mark=$([ "${SEL[i]}" = 1 ] && printf '%s[x]%s' "$G" "$N" || printf '[ ]')
            printf '   %s%2d)%s %s %s\n' "$A" "$((i + 1))" "$N" "$mark" "$(app_field "$i" 2)"
        done
        printf '  %s?%s ' "$A" "$N"
        read -r ans </dev/tty || ans=""
        [ -z "$ans" ] && break
        for x in $ans; do
            if [[ $x =~ ^[0-9]+$ ]] && [ "$x" -ge 1 ] && [ "$x" -le ${#APP_CATALOG[@]} ]; then
                SEL[$((x - 1))]=$((1 - SEL[$((x - 1))]))
            else
                warn "нет пункта $x"
            fi
        done
    done
fi

APP_IDS=() APP_PKGS=()
for i in "${!APP_CATALOG[@]}"; do
    [ "${SEL[i]}" = 1 ] || continue
    APP_IDS+=("$(app_field "$i" 1)")
    read -ra pk <<<"$(app_field "$i" 3)"
    APP_PKGS+=("${pk[@]}")
done
ok "Программы: ${APP_IDS[*]:-никаких}"

if printf '%s\n' "${APP_IDS[@]}" | grep -qx discord; then
    choose DISCORD_MOD "Discord" none \
        "none|как есть" \
        "vencord|Vencord — плагины и темы, патч обычного Discord" \
        "betterdiscord|BetterDiscord — плагины и темы" \
        "vesktop|Vesktop — отдельный клиент со встроенным Vencord, лучше на Wayland"
    # Vesktop заменяет обычный Discord
    if [ "$DISCORD_MOD" = vesktop ]; then
        mapfile -t APP_PKGS < <(printf '%s\n' "${APP_PKGS[@]}" | sed 's/^discord$/vesktop-bin/')
    fi
    [ "$DISCORD_MOD" = betterdiscord ] && APP_PKGS+=(betterdiscordctl)
else
    DISCORD_MOD=none
fi

declare -A BROWSER_PKG=([helium]=helium-browser-bin [firefox]=firefox [zen]=zen-browser-bin
    [chromium]=chromium [brave]=brave-bin [vivaldi]=vivaldi [none]="")
declare -A FILES_PKG=([thunar]=thunar [nautilus]=nautilus [dolphin]=dolphin [nemo]=nemo [yazi]=yazi [none]="")
declare -A SHELL_PKGS=([zsh]="zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions" [fish]=fish [bash]=bash-completion)

printf '\n  %sИтого:%s %s · %s · %s · файлы: %s · программы: %s%s\n' "$BOLD" "$N" \
    "$TERMINAL" "$SHELL_CHOICE" "$BROWSER" "$FILES" "${APP_IDS[*]:-нет}" \
    "$([ "$DISCORD_MOD" != none ] && printf ' · discord: %s' "$DISCORD_MOD")"
ask "Начинаем?" y || die "отменено"

sudo -v || die "без sudo не поставить пакеты"
# держим sudo живым, пока идёт установка
while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done &

# с --yes pacman и paru тоже не спрашивают; без него их вопросы остаются: видно, что ставится
noconfirm=()
[ "$YES" = 1 ] && noconfirm=(--noconfirm)

# ── пакеты ───────────────────────────────────────────────────────────
step "Пакеты"
PKGS=(
    niri quickshell xwayland-satellite git curl xdg-utils
    networkmanager pipewire pipewire-pulse wireplumber upower pacman-contrib libnotify
    polkit-gnome gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk qt6ct adw-gtk-theme
    ttf-terminus-nerd noto-fonts noto-fonts-emoji
    wl-clipboard brightnessctl playerctl pavucontrol fastfetch base-devel
    "$TERMINAL"
)
read -ra sp <<<"${SHELL_PKGS[$SHELL_CHOICE]}"
PKGS+=("${sp[@]}")

missing=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done

if [ ${#missing[@]} -eq 0 ]; then
    ok "базовые пакеты уже установлены"
else
    info "нужно поставить: ${missing[*]}"
    if ask "Обновить систему вместе с установкой (pacman -Syu)? На Arch так правильнее" y; then
        sudo pacman -Syu --needed "${noconfirm[@]}" "${missing[@]}"
    else
        sudo pacman -S --needed "${noconfirm[@]}" "${missing[@]}"
    fi
    ok "базовые пакеты установлены"
fi

# paru должен не просто быть, а запускаться: paru-bin собран под конкретную libalpm
# и после обновления pacman (libalpm.so.N → N+1) не стартует
paru_ok() { paru --version &>/dev/null; }

# build_aur <пакет> — собрать из AUR и поставить; сборочные зависимости (-r) удаляются после сборки.
# Не makepkg -si: он ставит пакет через «sudo -k» и заново спрашивает пароль (а с --yes зависает)
build_aur() {
    local tmp rc=0
    tmp=$(mktemp -d)
    git clone -q --depth 1 "https://aur.archlinux.org/$1.git" "$tmp/$1" \
        && (cd "$tmp/$1" && makepkg -sr --noconfirm) \
        && sudo pacman -U --noconfirm "$tmp/$1/$1"-[0-9]*.pkg.tar.zst || rc=1
    rm -rf "$tmp"
    return $rc
}

# убрать неработающий paru, чтобы на его место встал другой (paru и paru-bin конфликтуют)
drop_paru() {
    # точные имена: `pacman -Qq paru` находит и paru-bin — тот провайдит paru
    local pkgs
    pkgs=$(pacman -Qq | grep -xE 'paru|paru-bin' || true)
    [ -z "$pkgs" ] || sudo pacman -Rdd --noconfirm $pkgs >/dev/null
}

if paru_ok; then
    ok "paru уже есть"
else
    command -v paru >/dev/null && { warn "paru установлен, но не запускается — переустанавливаю"; drop_paru; }
    if pacman -Si paru &>/dev/null; then
        sudo pacman -S --needed --noconfirm paru || true
    fi
    if ! paru_ok; then
        info "собираю paru-bin из AUR"
        drop_paru
        build_aur paru-bin || true
    fi
    if ! paru_ok; then
        warn "paru-bin не запускается (собран под другую версию pacman) — собираю paru из исходников, это несколько минут"
        drop_paru
        build_aur paru || true
    fi
    paru_ok || die "paru не запускается: $(paru --version 2>&1 | tail -1)"
    ok "paru: $(paru --version | head -1)"
fi

# браузер, файловый менеджер и программы — через paru: из репозиториев, если есть, иначе из AUR
# иконки Gruvbox Plus — из AUR, поэтому не в PKGS; shell включает их в GTK и Qt (темы Qt и GTK)
EXTRA=("${APP_PKGS[@]}" gruvbox-plus-icon-theme)
[ -n "${BROWSER_PKG[$BROWSER]}" ] && EXTRA+=("${BROWSER_PKG[$BROWSER]}")
[ -n "${FILES_PKG[$FILES]}" ] && EXTRA+=("${FILES_PKG[$FILES]}")

if printf '%s\n' "${EXTRA[@]}" | grep -qx steam && ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    if ask "Steam нужен репозиторий multilib (32-битные библиотеки). Включить?" y; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
        sudo pacman -Sy
        ok "multilib включён"
    else
        mapfile -t EXTRA < <(printf '%s\n' "${EXTRA[@]}" | grep -vx steam)
        warn "Steam пропущен"
    fi
fi

missing=()
for p in "${EXTRA[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done
if [ ${#missing[@]} -eq 0 ]; then
    ok "программы уже установлены"
else
    info "ставлю через paru: ${missing[*]}"
    paru -S --needed --skipreview "${noconfirm[@]}" "${missing[@]}" || true
    # paru мог упасть на одном пакете — сверяем, что поставилось на самом деле
    failed=()
    for p in "${missing[@]}"; do pacman -Qq "$p" &>/dev/null || failed+=("$p"); done
    if [ ${#failed[@]} -eq 0 ]; then
        ok "программы установлены"
    else
        warn "не поставились: ${failed[*]} — см. вывод paru выше; повторить: paru -S ${failed[*]}"
    fi
fi

# ── сам shell ────────────────────────────────────────────────────────
step "nopox-shell → $DEST"
if [ -d "$DEST/.git" ] && git -C "$DEST" remote get-url origin 2>/dev/null | grep -q "nopox-shell"; then
    git -C "$DEST" fetch --quiet origin "$BRANCH" || die "не удалось скачать ветку $BRANCH"
    # клон мог быть на другой ветке (или его ветку удалили) — тогда переключаем на нужную
    if [ "$(git -C "$DEST" rev-parse --abbrev-ref HEAD)" != "$BRANCH" ] \
        || ! git -C "$DEST" rev-parse --abbrev-ref '@{u}' &>/dev/null; then
        git -C "$DEST" checkout -q -B "$BRANCH" "origin/$BRANCH" || die "в $DEST локальные правки мешают переключиться на $BRANCH"
        git -C "$DEST" branch -q -u "origin/$BRANCH"
    else
        git -C "$DEST" merge -q --ff-only "origin/$BRANCH" || die "в $DEST локальные правки мешают обновиться (git status)"
    fi
    ok "уже установлен — обновлён до $(git -C "$DEST" log --oneline -1)"
else
    backup "$DEST"
    git clone -q --branch "$BRANCH" "$REPO" "$DEST"
    ok "склонирован: $(git -C "$DEST" log --oneline -1)"
fi
info "обновления потом — сам shell: nopox ↑ на панели"
mkdir -p "$HOME/Pictures/Wallpapers"

# выбор терминала и файлового менеджера — в настройки shell (Mod+T, Mod+E, окна обновлений и т.п.)
set_setting shell.terminal "$TERMINAL"
set_setting shell.files "$FILES"

# ── niri ─────────────────────────────────────────────────────────────
step "Конфиг niri"
conf="$NIRI_DIR/config.kdl"
# ~/.config/niri/nopox/ — по файлу на раздел (input, displays, layout, window-rules, …).
# Shell перегенерирует их при запуске; стартовые нужны, чтобы niri загрузил конфиг ещё до shell.
mkdir -p "$NIRI_DIR/nopox"
for f in "$DEST"/extras/niri/nopox/*.kdl; do
    [ -f "$NIRI_DIR/nopox/$(basename "$f")" ] || cp "$f" "$NIRI_DIR/nopox/"
done

if [ -f "$conf" ] && grep -q '^include "nopox/main.kdl"' "$conf"; then
    ok "nopox уже подключён к вашему config.kdl"
elif [ -f "$conf" ] && grep -qE '^include "nopox(-binds)?\.kdl"' "$conf"; then
    ok "старая схема nopox — shell сам переложит её в ~/.config/niri/nopox/ при запуске"
elif [ ! -f "$conf" ] || { [ "$KEEP_NIRI" = 0 ] && ask "Заменить ваш config.kdl конфигом nopox? Старый уйдёт в бэкап" y; }; then
    backup "$conf"
    cp "$DEST/extras/niri/config.kdl" "$conf"
    ok "config.kdl nopox установлен"
else
    # в одном файле может быть только один binds — поэтому всё своё nopox держит во включаемых файлах;
    # они в конце, значит одноимённые клавиши (Mod+D и т.п.) берутся из nopox
    cp "$conf" "$conf.bak-$STAMP"
    info "старое — в $conf.bak-$STAMP"
    {
        echo
        echo "// >>> nopox-shell >>> (добавлено install.sh)"
        echo 'include "nopox/main.kdl"'
        echo 'include "nopox/keys.kdl"'
        echo "// <<< nopox-shell <<<"
    } >> "$conf"
    ok "к вашему config.kdl дописаны include nopox"
    warn "флаги в ваших секциях input / layout (например, tap) окно настроек (Mod+S) выключить не сможет"
fi

if command -v niri >/dev/null && ! niri validate -c "$conf" >/dev/null 2>&1; then
    warn "niri validate не принял конфиг — возвращаю прежний"
    [ -f "$conf.bak-$STAMP" ] && mv "$conf.bak-$STAMP" "$conf"
    niri validate -c "$conf" 2>&1 | tail -5
    die "исправьте config.kdl и запустите установщик снова"
fi
ok "niri validate: конфиг корректный"

# ── терминал ─────────────────────────────────────────────────────────
step "Терминал: $TERMINAL"
declare -A TERM_CONF=(
    [kitty]="kitty/kitty.conf:$HOME/.config/kitty/kitty.conf"
    [alacritty]="alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
    [ghostty]="ghostty/config:$HOME/.config/ghostty/config"
    [foot]="foot/foot.ini:$HOME/.config/foot/foot.ini"
)
src="$DEST/extras/${TERM_CONF[$TERMINAL]%%:*}"
dst="${TERM_CONF[$TERMINAL]#*:}"
if [ ! -f "$dst" ]; then
    install -Dm644 "$src" "$dst"
    ok "конфиг в цветах Gruvbox + Terminess"
elif cmp -s "$dst" "$src"; then
    ok "уже стоит конфиг nopox"
elif ask "Заменить ваш конфиг $TERMINAL на Gruvbox + Terminess от nopox?" n; then
    backup "$dst"
    install -Dm644 "$src" "$dst"
    ok "конфиг заменён"
else
    info "оставил ваш конфиг"
fi

# fastfetch в стиле панели — только если своего конфига нет (about в меню берёт конфиг из shell сам)
ff="$HOME/.config/fastfetch/config.jsonc"
if [ ! -f "$ff" ]; then
    install -Dm644 "$DEST/extras/fastfetch/config.jsonc" "$ff"
    ok "fastfetch: конфиг nopox"
fi

# ── оболочка ─────────────────────────────────────────────────────────
step "Оболочка: $SHELL_CHOICE"
case "$SHELL_CHOICE" in
    zsh)
        if [ ! -f "$HOME/.zshrc" ]; then
            cp "$DEST/extras/shell/zshrc" "$HOME/.zshrc"
            ok "~/.zshrc: приглашение как панель nopox, подсказки, подсветка"
        elif grep -q "nopox-shell" "$HOME/.zshrc"; then
            ok "~/.zshrc уже от nopox"
        elif ask "Заменить ваш ~/.zshrc на nopox (приглашение как панель, подсказки, подсветка)?" n; then
            backup "$HOME/.zshrc"
            cp "$DEST/extras/shell/zshrc" "$HOME/.zshrc"
            ok "~/.zshrc заменён"
        else
            info "оставил ваш ~/.zshrc"
        fi
        ;;
    fish)
        fp="$HOME/.config/fish/functions/fish_prompt.fish"
        install -Dm644 "$DEST/extras/shell/nopox.fish" "$HOME/.config/fish/conf.d/nopox.fish"
        if [ ! -f "$fp" ] || grep -q "nopox-shell" "$fp"; then
            install -Dm644 "$DEST/extras/shell/fish_prompt.fish" "$fp"
            ok "приглашение fish как панель nopox"
        elif ask "Заменить ваше приглашение fish на nopox?" n; then
            backup "$fp"
            install -Dm644 "$DEST/extras/shell/fish_prompt.fish" "$fp"
            ok "приглашение fish заменено"
        fi
        ;;
    bash)
        if grep -q ">>> nopox-shell >>>" "$HOME/.bashrc" 2>/dev/null; then
            ok "~/.bashrc уже с приглашением nopox"
        elif ask "Добавить в ~/.bashrc приглашение как панель nopox?" y; then
            { echo; cat "$DEST/extras/shell/bashrc"; } >> "$HOME/.bashrc"
            ok "добавлено в ~/.bashrc"
        fi
        ;;
esac
target=$(command -v "$SHELL_CHOICE")
if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$target" ]; then
    ok "$SHELL_CHOICE уже оболочка по умолчанию"
else
    sudo chsh -s "$target" "$USER" && ok "оболочка по умолчанию: $target (с нового входа)"
fi

# ── приложения по умолчанию ──────────────────────────────────────────
step "Приложения по умолчанию"
if [ -n "${BROWSER_PKG[$BROWSER]}" ] && d=$(desktop_of "${BROWSER_PKG[$BROWSER]}") && [ -n "$d" ]; then
    xdg-settings set default-web-browser "$d" && ok "браузер: $d"
fi
if [ -n "${FILES_PKG[$FILES]}" ] && [ "$FILES" != yazi ] && d=$(desktop_of "${FILES_PKG[$FILES]}") && [ -n "$d" ]; then
    xdg-mime default "$d" inode/directory && ok "папки открывает: $d"
fi
[ "$FILES" = yazi ] && ok "файлы: yazi в терминале (Mod+E)"

# ── Discord ──────────────────────────────────────────────────────────
case "$DISCORD_MOD" in
    vencord)
        step "Discord: Vencord"
        # пакет discord — только загрузчик: сам Discord докачивает себя в ~/.config/discord при первом запуске,
        # поэтому Vencord ставится от пользователя туда, а не в /opt
        tmp=$(mktemp)
        curl -fsSL -o "$tmp" https://github.com/Vendicated/VencordInstaller/releases/latest/download/VencordInstallerCli-linux \
            || die "не скачался установщик Vencord"
        sudo install -Dm755 "$tmp" /usr/local/bin/VencordInstallerCli
        rm -f "$tmp"
        if compgen -G "$HOME/.config/discord/app-*/resources/app.asar" >/dev/null; then
            if VencordInstallerCli -install -location "$HOME/.config/discord" </dev/null >/dev/null 2>&1; then
                ok "Vencord установлен"
            else
                warn "Vencord не встал — попробуйте: VencordInstallerCli -install -location ~/.config/discord"
            fi
        else
            warn "Discord ещё не запускался — запустите его один раз, закройте и выполните:"
            info "VencordInstallerCli -install -location ~/.config/discord"
        fi
        info "Discord обновляет себя сам; если Vencord пропал: VencordInstallerCli -repair -location ~/.config/discord"
        ;;
    betterdiscord)
        step "Discord: BetterDiscord"
        if [ -d "$HOME/.config/discord" ]; then
            betterdiscordctl install && ok "BetterDiscord установлен"
        else
            warn "Discord ещё ни разу не запускался — запустите его, закройте и выполните: betterdiscordctl install"
        fi
        info "после обновлений Discord: betterdiscordctl reinstall"
        ;;
    vesktop)
        step "Discord: Vesktop"
        ok "Vesktop установлен вместо Discord — Vencord уже внутри"
        ;;
esac

# ── greeter ──────────────────────────────────────────────────────────
step "Greeter (экран входа)"
if [ "$GREETER" = no ] || ! ask "Поставить greeter nopox для greetd?" y; then
    info "пропущено — потом можно: sudo $DEST/extras/install-greeter.sh"
else
    sudo pacman -S --needed --noconfirm greetd
    sudo bash "$DEST/extras/install-greeter.sh" | sed 's/^/  /'

    dm=$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)
    if [ "$dm" = "greetd.service" ]; then
        ok "greetd уже включён"
    elif [ -n "$dm" ]; then
        if ask "Сейчас вход через $dm. Заменить его на greetd с greeter nopox?" n; then
            sudo systemctl disable "$dm"
            sudo systemctl enable greetd
            ok "greetd включён вместо $dm — заработает после перезагрузки"
        else
            info "оставил $dm; переключить потом: sudo systemctl disable $dm && sudo systemctl enable greetd"
        fi
    elif ask "Включить greetd (вход в систему через greeter)?" y; then
        sudo systemctl enable greetd
        ok "greetd включён — заработает после перезагрузки"
    fi
fi

# ── итог ─────────────────────────────────────────────────────────────
step "Готово"
systemctl is-active --quiet NetworkManager \
    || warn "NetworkManager не запущен — модуль net покажет offline (sudo systemctl enable --now NetworkManager)"

if [ -n "${NIRI_SOCKET:-}" ] && pgrep -x niri >/dev/null; then
    if ask "Вы сейчас в niri — перезапустить shell?" y; then
        pkill -x qs || true
        niri msg action spawn -- qs
        ok "shell перезапущен"
    fi
else
    info "Войдите в сессию niri: через greeter или командой niri-session из консоли."
fi

cat <<EOF

  ${A}Mod+D${N}        меню             ${A}Mod+S${N}         настройки
  ${A}Mod+T${N}        $TERMINAL$(printf '%*s' $((17 - ${#TERMINAL})) '')${A}Mod+Shift+W${N}   обои
  ${A}Mod+Shift+D${N}  программы        ${A}Super+Alt+L${N}   блокировка$([ "$FILES" != none ] && printf '\n  %sMod+E%s        %s' "$A" "$N" "$FILES")
  ${A}Mod+Shift+/${N}  все клавиши niri

  ${D}$REPO${N}
EOF
