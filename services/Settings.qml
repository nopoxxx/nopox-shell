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

    // заменить все ключи с префиксом разом (откат настроек мониторов)
    function replacePrefix(prefix, obj) {
        const v = {};
        for (const k in values)
            if (!k.startsWith(prefix)) v[k] = values[k];
        Object.assign(v, obj);
        values = v;
        save.restart();
    }

    function snapshotPrefix(prefix) {
        const out = {};
        for (const k in values)
            if (k.startsWith(prefix)) out[k] = values[k];
        return out;
    }

    function refreshOutputs() { outputsProc.running = true; }

    function writeNiri() {
        if (greeterMode) return;
        const outs = {};
        for (const k in values) {
            const m = k.match(/^niri\.out\.(.+)\.(\w+)$/);
            if (!m) continue;
            if (!outs[m[1]]) outs[m[1]] = {};
            outs[m[1]][m[2]] = values[k];
        }
        niriView.setText(S.niriKdl(get, outs));
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
                    const modeStr = m => m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
                    root.outputs = Object.values(o).map(x => {
                        // режимы без повторов: сначала крупнее, внутри — чаще
                        const modes = [...new Set((x.modes ?? [])
                            .slice().sort((a, b) => b.width * b.height - a.width * a.height || b.refresh_rate - a.refresh_rate)
                            .map(modeStr))];
                        const cur = x.modes?.[x.current_mode];
                        const pref = (x.modes ?? []).find(m => m.is_preferred);
                        return {
                            name: x.name,
                            make: x.make ?? "",
                            model: x.model ?? "",
                            physical: x.physical_size ?? [0, 0],
                            modes,
                            mode: cur ? modeStr(cur) : "",
                            preferred: pref ? modeStr(pref) : "",
                            enabled: x.logical !== null && x.current_mode !== null,
                            scale: x.logical?.scale ?? 1,
                            transform: S.niriTransform(x.logical?.transform),
                            x: x.logical?.x ?? 0,
                            y: x.logical?.y ?? 0,
                            w: x.logical?.width ?? 0,
                            h: x.logical?.height ?? 0,
                            vrrSupported: x.vrr_supported ?? false,
                            vrr: x.vrr_enabled ?? false
                        };
                    }).sort((a, b) => a.name.localeCompare(b.name));
                } catch (e) {
                    console.warn("niri outputs:", e);
                }
            }
        }
    }
}
