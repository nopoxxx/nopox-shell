pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Текущие обои, локальная коллекция, фирменные обои ochre и загрузка с wallhaven.cc
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/ochre/wallpaper"

    property string current: ""
    property string fill: "fill"           // fill | fit | stretch
    readonly property var fillModes: ["fill", "fit", "stretch"]
    property var local: []                 // пути к файлам в dir
    property string downloading: ""        // id обоев, которые сейчас качаются

    // окно выбора
    property bool pickerOpen: false
    property string pickerSource: "local"  // local | wallhaven

    // Фирменные обои (extras/wallpapers): sundown, horizon и field нарисованы под каждый акцент
    // (accents/<акцент>-<имя>.png, у акцента ochre — ochre-<имя>.png), tty — один. Стоят фирменные — при смене
    // акцента меняются на его вариант; обоев ещё нет совсем (первый запуск) — ставится horizon.
    readonly property string brandDir: Quickshell.shellDir + "/extras/wallpapers"
    readonly property var brandNames: ["horizon", "sundown", "field", "tty"]
    readonly property string accent: Settings.get("shell.accent")
    readonly property var brand: brandNames.map(n => brandPath(n, accent))

    function brandPath(name, acc) {
        return name === "tty" || acc === "ochre" ? brandDir + "/ochre-" + name + ".png"
            : brandDir + "/accents/" + acc + "-" + name + ".png";
    }

    // имя фирменных обоев по пути, "" — свои
    function brandNameOf(path) {
        if (!path.startsWith(brandDir + "/")) return "";
        const m = path.match(/[-/](horizon|sundown|field|tty)\.png$/);
        return m ? m[1] : "";
    }

    // до чтения настроек акцент — по умолчанию: не дёргать обои туда-обратно
    onAccentChanged: {
        if (!Settings.writable) return;
        const n = brandNameOf(current);
        if (n && brandPath(n, accent) !== current) set(brandPath(n, accent));
    }

    // файла состояния нет — обои ни разу не выбирали; ставим фирменные, когда настройки (акцент) уже прочитаны
    property bool _noState: false
    readonly property bool _wantDefault: _noState && Settings.writable && current === ""
    on_WantDefaultChanged: if (_wantDefault) set(brandPath("horizon", accent))

    function set(path) {
        current = path;
        state.setText(path + "\n");
    }

    function setFill(mode) {
        if (!fillModes.includes(mode)) return;
        fill = mode;
        fillState.setText(mode + "\n");
    }

    function cycleFill() {
        setFill(fillModes[(fillModes.indexOf(fill) + 1) % fillModes.length]);
    }

    function refresh() { lister.running = true; }

    function localPathFor(w) {
        return dir + "/wallhaven-" + w.id + w.path.slice(w.path.lastIndexOf("."));
    }

    function download(w) {
        const dest = localPathFor(w);
        if (local.includes(dest)) { set(dest); return; }
        if (downloading) return;
        downloading = w.id;
        dl.dest = dest;
        dl.command = ["sh", "-c", 'curl -fsSL -o "$1.part" "$2" && mv "$1.part" "$1"', "sh", dest, w.path];
        dl.running = true;
    }

    // поиск на wallhaven; cb({ items, lastPage }) или cb({ error })
    function search(query, page, cb) {
        const p = {
            q: query,
            categories: "110",   // general + anime
            purity: "100",       // только SFW
            sorting: query ? "relevance" : "toplist",
            topRange: "1M",
            atleast: "1920x1080",
            ratios: "landscape",
            page: page
        };
        const qs = Object.keys(p).map(k => k + "=" + encodeURIComponent(p[k])).join("&");
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { cb({ error: "wallhaven: HTTP " + xhr.status }); return; }
            try {
                const r = JSON.parse(xhr.responseText);
                cb({ items: r.data, lastPage: r.meta.last_page });
            } catch (e) {
                cb({ error: "wallhaven: " + e });
            }
        };
        xhr.open("GET", "https://wallhaven.cc/api/v1/search?" + qs);
        xhr.send();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir, stateFile.slice(0, stateFile.lastIndexOf("/"))])

    FileView {
        id: state
        // после переезда с nopox-shell: ~/.local/state/nopox → ochre (Settings.renamed)
        path: Settings.renamed ? root.stateFile : ""
        onLoaded: root.current = text().trim()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) root._noState = true; }
    }

    FileView {
        id: fillState
        path: Settings.renamed ? root.stateFile + "-fill" : ""
        onLoaded: {
            const m = text().trim();
            if (root.fillModes.includes(m)) root.fill = m;
        }
    }

    Process {
        id: lister
        running: true
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.local = this.text.split("\n").filter(l => l).sort()
        }
    }

    Process {
        id: dl

        property string dest

        onExited: code => {
            root.downloading = "";
            if (code === 0) {
                root.set(dest);
                root.refresh();
            }
        }
    }
}
