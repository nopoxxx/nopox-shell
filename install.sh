#!/usr/bin/env bash
# nopox-shell — установщик для Arch Linux и производных (CachyOS, EndeavourOS, …)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nopoxxx/nopox-shell/main/install.sh)
#
# Флаги:
#   --yes               не задавать вопросов, всё по умолчанию
#   --no-greeter        не ставить greeter (greetd)
#   --keep-niri-config  не заменять config.kdl niri, только дописать блок nopox
#   --branch <ветка>    ветка репозитория (по умолчанию main)
#
# Ничего не удаляет: всё, что заменяется, переезжает в *.bak-<дата>.
set -euo pipefail

REPO=https://github.com/nopoxxx/nopox-shell
BRANCH=main
YES=0
GREETER=ask
KEEP_NIRI=0
DEST="$HOME/.config/quickshell"
NIRI_DIR="$HOME/.config/niri"
STAMP=$(date +%Y%m%d-%H%M%S)

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --no-greeter) GREETER=no ;;
        --keep-niri-config) KEEP_NIRI=1 ;;
        --branch) BRANCH=${2:?нужно имя ветки}; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
sudo -v || die "без sudo не поставить пакеты"
# держим sudo живым, пока идёт установка
while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done &

# ── пакеты ───────────────────────────────────────────────────────────
step "Пакеты"
PKGS=(
    niri quickshell xwayland-satellite kitty git curl
    networkmanager pipewire pipewire-pulse wireplumber upower pacman-contrib libnotify
    polkit-gnome gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    ttf-terminus-nerd noto-fonts noto-fonts-emoji
    wl-clipboard brightnessctl playerctl pavucontrol fastfetch base-devel
)
missing=()
for p in "${PKGS[@]}"; do pacman -Qq "$p" &>/dev/null || missing+=("$p"); done

# с --yes pacman тоже не спрашивает; без него — его вопрос остаётся: видно, что ставится
noconfirm=()
[ "$YES" = 1 ] && noconfirm=(--noconfirm)

if [ ${#missing[@]} -eq 0 ]; then
    ok "всё уже установлено"
else
    info "нужно поставить: ${missing[*]}"
    if ask "Обновить систему вместе с установкой (pacman -Syu)? На Arch так правильнее" y; then
        sudo pacman -Syu --needed "${noconfirm[@]}" "${missing[@]}"
    else
        sudo pacman -S --needed "${noconfirm[@]}" "${missing[@]}"
    fi
    ok "пакеты установлены"
fi

if command -v paru >/dev/null; then
    ok "paru уже есть"
elif pacman -Si paru &>/dev/null; then
    sudo pacman -S --needed --noconfirm paru
    ok "paru из репозитория"
else
    info "paru нет в репозиториях — собираю paru-bin из AUR"
    tmp=$(mktemp -d)
    git clone -q --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "paru собран"
fi

# ── сам shell ────────────────────────────────────────────────────────
step "nopox-shell → $DEST"
if [ -d "$DEST/.git" ] && git -C "$DEST" remote get-url origin 2>/dev/null | grep -q "nopox-shell"; then
    git -C "$DEST" pull --ff-only --quiet
    ok "уже установлен — обновлён до $(git -C "$DEST" log --oneline -1)"
else
    backup "$DEST"
    git clone -q --branch "$BRANCH" "$REPO" "$DEST"
    ok "склонирован: $(git -C "$DEST" log --oneline -1)"
fi
info "обновления потом — сам shell: nopox ↑ на панели"
mkdir -p "$HOME/Pictures/Wallpapers"

# ── niri ─────────────────────────────────────────────────────────────
step "Конфиг niri"
mkdir -p "$NIRI_DIR"
conf="$NIRI_DIR/config.kdl"

if [ ! -f "$NIRI_DIR/nopox.kdl" ]; then
    # стартовый: потом его перегенерирует окно настроек (Mod+S)
    cp "$DEST/extras/niri/nopox.kdl" "$NIRI_DIR/nopox.kdl"
fi

if [ -f "$conf" ] && grep -q 'include "nopox.kdl"' "$conf"; then
    ok "nopox уже подключён к вашему config.kdl"
elif [ ! -f "$conf" ] || { [ "$KEEP_NIRI" = 0 ] && ask "Заменить ваш config.kdl конфигом nopox? Старый уйдёт в бэкап" y; }; then
    backup "$conf"
    cp "$DEST/extras/niri/config.kdl" "$conf"
    ok "config.kdl nopox установлен"
else
    cp "$conf" "$conf.bak-$STAMP"
    info "старое — в $conf.bak-$STAMP"
    {
        echo
        echo "// >>> nopox-shell >>> (добавлено install.sh)"
        grep -v '^// ' "$DEST/extras/niri.kdl"
        echo "// <<< nopox-shell <<<"
    } >> "$conf"
    ok "к вашему config.kdl дописан блок nopox"
    warn "секции input / layout / cursor / animations в вашем config.kdl могут перебивать окно настроек (Mod+S)"
fi

if command -v niri >/dev/null && ! niri validate -c "$conf" >/dev/null 2>&1; then
    warn "niri validate не принял конфиг — возвращаю прежний"
    [ -f "$conf.bak-$STAMP" ] && mv "$conf.bak-$STAMP" "$conf"
    niri validate -c "$conf" 2>&1 | tail -5
    die "исправьте config.kdl и запустите установщик снова"
fi
ok "niri validate: конфиг корректный"

# ── kitty ────────────────────────────────────────────────────────────
step "kitty"
kconf="$HOME/.config/kitty/kitty.conf"
if [ ! -f "$kconf" ]; then
    install -Dm644 "$DEST/extras/kitty/kitty.conf" "$kconf"
    ok "конфиг kitty в цветах Gruvbox"
elif cmp -s "$kconf" "$DEST/extras/kitty/kitty.conf"; then
    ok "уже стоит конфиг nopox"
elif ask "Заменить конфиг kitty на Gruvbox + Terminess от nopox?" n; then
    backup "$kconf"
    install -Dm644 "$DEST/extras/kitty/kitty.conf" "$kconf"
    ok "конфиг kitty заменён"
else
    info "оставил ваш kitty.conf"
fi

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
  ${A}Mod+Shift+D${N}  программы        ${A}Mod+Shift+W${N}   обои
  ${A}Mod+T${N}        терминал         ${A}Super+Alt+L${N}   блокировка
  ${A}Mod+Shift+/${N}  все клавиши niri

  ${D}$REPO${N}
EOF
