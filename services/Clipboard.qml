pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// История буфера обмена на cliphist. Пока жив shell, `wl-paste --watch cliphist store` пишет каждую копию
// (текст и картинки) в базу cliphist; окно — ClipboardWindow (Mod+Shift+V).
// Пароли из менеджеров (KeePassXC и т.п. помечают их как sensitive) cliphist не сохраняет.
Singleton {
    id: root

    property bool available: false
    property bool checked: false
    property var entries: []        // [{ line, id, text, image }] — новые сверху
    property bool loading: false

    readonly property bool watching: available && !Settings.greeterMode
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nopox-clip"

    // проверяется при старте и при каждом открытии окна, пока не найден: cliphist могли поставить после запуска shell
    Process {
        id: probe
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null"]
        running: true
        onExited: code => {
            root.available = code === 0;
            root.checked = true;
            if (root.available) root.refresh();
        }
    }

    // без --type: wl-paste сам выберет обычный текст (UTF-8) или картинку. С `--type text` он брал первый
    // попавшийся text/* — у браузеров это text/x-moz-url в UTF-16, и в историю шли «h\0t\0t\0p\0…»
    Process {
        id: watcher
        running: root.watching
        // qs при выходе по сигналу детей не убивает: без pkill каждый перезапуск shell добавлял бы ещё одного писателя
        command: ["sh", "-c", 'pkill -u "$(id -u)" -xf "(.*/)?wl-paste (--type [a-z]+ )?--watch cliphist store"; exec wl-paste --watch cliphist store']
        // упал (перезапуск композитора, нет дисплея) — поднять через пару секунд, без частого цикла
        onExited: if (root.watching) restart.start()
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: watcher.running = Qt.binding(() => root.watching)
    }

    // «[[ binary data 39 KiB png 501x502 ]]» → { kind, size, dims }
    function parseImage(text) {
        const m = /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/.exec(text);
        return m ? { size: m[1], kind: m[2], dims: m[3].replace("x", "×") } : null;
    }

    function refresh() {
        if (!available) { if (!probe.running) probe.running = true; return; }
        if (lister.running) return;
        loading = true;
        lister.running = true;
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const text = line.slice(tab + 1);
                    out.push({ line, id: line.slice(0, tab), text, image: root.parseImage(text) });
                }
                root.entries = out;
                root.loading = false;
            }
        }
    }

    // строку из `cliphist list` cliphist понимает целиком: id берёт сам
    function copy(e) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", e.line]);
    }

    // картинку для предпросмотра декодированную храним по id — удаляем вместе с записью
    function previewPath(e) {
        return e.image ? cacheDir + "/" + e.id + "." + e.image.kind : "";
    }

    function remove(e) {
        entries = entries.filter(x => x.id !== e.id);
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete; [ -z "$2" ] || rm -f "$2"', "sh", e.line, previewPath(e)]);
    }

    function wipe() {
        entries = [];
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf "$1"', "sh", cacheDir]);
    }
}
