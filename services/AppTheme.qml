pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Темы приложений вслед за shell (настройки shell.theme.*, shell.accent, shell.fontSize, niri.cursor.size):
//   GTK — ~/.config/gtk-{3,4}.0/nopox.css (палитра Gruvbox и акцент; @import в начале gtk.css)
//         и gsettings org.gnome.desktop.interface (тёмная схема, adw-gtk3-dark, акцент, шрифт, курсор);
//   Qt  — ~/.config/qt6ct/ (палитра, Fusion, шрифт); QT_QPA_PLATFORMTHEME задаёт misc.kdl;
//   btop — ~/.config/btop/themes/nopox.theme и color_theme / theme_background / rounded_corners в btop.conf.
// Что писать — S.themeFiles() и S.themeGsettings(); здесь только запись, и лишь когда результат изменился.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // весь результат одной строкой: настройки меняются часто, а пишем только при реальной разнице
    readonly property string state: Settings.writable
        ? JSON.stringify({
            files: S.themeFiles(k => Settings.get(k), home),
            gsettings: S.themeGsettings(k => Settings.get(k))
        })
        : ""
    property string _applied: ""

    onStateChanged: debounce.restart()

    function apply() {
        if (!state || state === _applied) return;
        if (writer.running) { debounce.restart(); return; }
        _applied = state;
        const s = JSON.parse(state);
        const args = [];
        for (const path in s.files) args.push(path, s.files[path]);
        args.push("--");
        for (const [key, value] of s.gsettings) args.push(key, value);
        writer.command = ["sh", "-c", `
            d=$1; shift
            # файлы: путь от ~/.config и содержимое; через временный файл — приложения не увидят половину
            while [ "$1" != "--" ]; do
                mkdir -p "$(dirname "$d/$1")"
                printf '%s' "$2" > "$d/$1.nopox-tmp" && mv -f "$d/$1.nopox-tmp" "$d/$1"
                shift 2
            done
            shift
            # nopox.css — последним среди @import в gtk.css: из одинаковых @define-color побеждает последний,
            # а остатки других тем (noctalia.css и т.п.) иначе перебили бы палитру. @import — до остальных правил
            for v in gtk-3.0 gtk-4.0; do
                f="$d/$v/gtk.css"
                if [ ! -s "$f" ]; then mkdir -p "$d/$v"; printf '@import "nopox.css";\\n' > "$f"; continue; fi
                last=$(awk '/^[[:space:]]*@import/ { n = NR } END { print n + 0 }' "$f")
                ours=$(grep -n '^@import "nopox.css";$' "$f" | tail -1 | cut -d: -f1)
                [ "$ours" = "$last" ] && continue
                sed -i '/^@import "nopox.css";$/d' "$f"
                last=$(awk '/^[[:space:]]*@import/ { n = NR } END { print n + 0 }' "$f")
                if [ "$last" -gt 0 ]; then sed -i "\${last}a @import \\"nopox.css\\";" "$f"; else sed -i '1i @import "nopox.css";' "$f"; fi
            done
            # btop: тема nopox, фон терминала, прямые углы — как рамки shell. btop перечитывает btop.conf
            # при запуске и переписывает при выходе, сохраняя эти значения; запущенный увидит их со следующего раза
            if [ -f "$d/btop/themes/nopox.theme" ]; then
                b="$d/btop/btop.conf"
                [ -f "$b" ] || printf '#? nopox: btop.conf создан nopox-shell, btop дополнит его сам\\n' > "$b"
                for kv in 'color_theme = "nopox"' 'theme_background = False' 'rounded_corners = False'; do
                    k=\${kv%% =*}
                    if grep -q "^$k = " "$b"; then sed -i "s|^$k = .*|$kv|" "$b"; else printf '%s\\n' "$kv" >> "$b"; fi
                done
            fi
            # gsettings: ключ и значение; пустое значение — вернуть по умолчанию
            while [ $# -gt 1 ]; do
                if [ -n "$2" ]; then gsettings set org.gnome.desktop.interface "$1" "$2"
                else gsettings reset org.gnome.desktop.interface "$1"; fi 2>/dev/null
                shift 2
            done`,
            "sh", home + "/.config"].concat(args);
        writer.running = true;
    }

    // стрелкой можно пролистать несколько значений подряд — пишем один раз
    Timer {
        id: debounce
        interval: 500
        onTriggered: root.apply()
    }

    Process {
        id: writer
        onExited: if (root.state !== root._applied) debounce.restart()
    }
}
