#!/usr/bin/env bash
# Ставит nopox-shell как greeter для greetd.
#   sudo ./extras/install-greeter.sh
# Копирует shell в /usr/share/nopox-shell, кладёт конфиг niri для greeter,
# создаёт каталоги синхронизации и переключает [default_session] в greetd.
# [initial_session] (автовход), если он есть, не трогает.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "запустите через sudo" >&2; exit 1; }

src=$(cd "$(dirname "$0")/.." && pwd)
dest=/usr/share/nopox-shell
conf=/etc/greetd/config.toml

rm -rf "$dest"
mkdir -p "$dest"
(cd "$src" && tar --exclude=.git --exclude=extras --exclude=docs --exclude=README.md --exclude=AGENTS.md --exclude=CLAUDE.md -cf - .) | tar -xf - -C "$dest"
chmod -R a+rX "$dest"

install -Dm644 "$src/extras/greeter/niri.kdl" /etc/greetd/nopox-niri.kdl

# общий каталог: настройки и обои пользователей (пишут их сессии) и состояние greeter
install -d -m755 /var/lib/nopox-greeter
install -d -m755 -o greeter -g greeter /var/lib/nopox-greeter/.greeter
getent passwd | awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1}' | while read -r u; do
    install -d -m755 -o "$u" -g "$(id -gn "$u")" "/var/lib/nopox-greeter/$u"
done

[ -f "$conf.orig" ] || cp "$conf" "$conf.orig"
sed -i '/^\[default_session\]/,/^\[/ s|^command = .*|command = "niri -c /etc/greetd/nopox-niri.kdl"|' "$conf"

echo "готово: greeter установлен, исходный конфиг greetd — $conf.orig"
grep -A2 '^\[default_session\]' "$conf"
