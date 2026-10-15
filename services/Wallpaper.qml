pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Текущие обои, локальная коллекция и загрузка с wallhaven.cc
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/nopox/wallpaper"

    property string current: ""
    property var local: []                 // пути к файлам в dir
    property string downloading: ""        // id обоев, которые сейчас качаются

    // окно выбора
    property bool pickerOpen: false
    property string pickerSource: "local"  // local | wallhaven

    function set(path) {
        current = path;
        state.setText(path + "\n");
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
        path: root.stateFile
        onLoaded: root.current = text().trim()
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
