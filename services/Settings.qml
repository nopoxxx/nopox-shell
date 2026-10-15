pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Настройки nopox: ~/.config/nopox/settings.json (только отличия от умолчаний)
// и сгенерированный из них ~/.config/niri/nopox.kdl.
// В greeter (NOPOX_GREETER=1) — только чтение копии настроек пользователя profile
// из /var/lib/nopox-greeter/<user>/, её туда кладёт GreeterSync из сессии пользователя.
Singleton {
    id: root

    readonly property bool greeterMode: Quickshell.env("NOPOX_GREETER") === "1"
    property string profile: ""
    readonly property string file: greeterMode
        ? (profile ? "/var/lib/nopox-greeter/" + profile + "/settings.json" : "")
        : Quickshell.env("HOME") + "/.config/nopox/settings.json"
    readonly property string niriFile: Quickshell.env("HOME") + "/.config/niri/nopox.kdl"

    property var values: ({})
    property bool loaded: false
    property var outputs: []
    property bool open: false   // окно настроек

    function get(key) {
        return key in values ? values[key] : S.defaultOf(key, outputs);
    }

    function isDefault(key) {
        return !(key in values);
    }

    function set(key, value) {
        const v = Object.assign({}, values);
        if (value === S.defaultOf(key, outputs)) delete v[key];
        else v[key] = value;
        values = v;
        save.restart();
    }

    function reset(key) {
        if (isDefault(key)) return;
        const v = Object.assign({}, values);
        delete v[key];
        values = v;
        save.restart();
    }

    function refreshOutputs() { outputsProc.running = true; }

    function writeNiri() {
        if (greeterMode) return;
        const scales = {};
        for (const k in values) {
            const m = k.match(/^niri\.out\.(.+)\.scale$/);
            if (m) scales[m[1]] = values[k];
        }
        niriView.setText(S.niriKdl(get, scales));
    }

    Component.onCompleted: if (!greeterMode) Quickshell.execDetached(["mkdir", "-p", file.slice(0, file.lastIndexOf("/"))])

    // небольшая задержка: стрелкой можно пролистать несколько значений подряд, а niri перечитает конфиг один раз
    Timer {
        id: save
        interval: 250
        onTriggered: {
            if (root.greeterMode) return;
            json.setText(JSON.stringify(root.values, null, 2) + "\n");
            root.writeNiri();
        }
    }

    FileView {
        id: json
        path: root.file
        onLoaded: {
            try { root.values = JSON.parse(text()); } catch (e) { console.warn("settings.json:", e); }
            root.loaded = true;
            root.writeNiri();   // схема могла измениться после обновления
        }
        onLoadFailed: {
            // greeter: у этого пользователя нет копии — умолчания, а не настройки предыдущего
            if (root.greeterMode) root.values = {};
            root.loaded = true;
            root.writeNiri();
        }
    }

    FileView {
        id: niriView
        path: root.greeterMode ? "" : root.niriFile
        blockLoading: false
    }

    Process {
        id: outputsProc
        running: true
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(this.text);
                    root.outputs = Object.values(o).map(x => ({
                        name: x.name,
                        make: x.make,
                        model: x.model,
                        scale: x.logical?.scale ?? 1,
                        mode: x.modes?.[x.current_mode]
                            ? x.modes[x.current_mode].width + "x" + x.modes[x.current_mode].height
                            : ""
                    }));
                } catch (e) {
                    console.warn("niri outputs:", e);
                }
            }
        }
    }
}
