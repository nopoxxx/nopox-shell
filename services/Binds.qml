pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "settings.js" as S

// Бинды niri: что действует сейчас (config.kdl + nopox-binds.kdl + свои) и свои изменения.
// Свои хранятся в настройке niri.keys и генерируются в ~/.config/niri/nopox-keys.kdl,
// который подключается в config.kdl последним — поэтому перекрывает одноимённые бинды.
// После записи — niri validate; если конфиг не прошёл, изменение откатывается.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/niri"
    readonly property var keys: Settings.get("niri.keys") ?? ({})

    property string configText: ""
    property var configBinds: []
    property var nopoxBinds: []
    property var actions: []          // [{ name, desc }] из niri msg action --help
    property string error: ""
    property var _prevKeys: null      // до последнего изменения — для отката

    readonly property bool included: /^\s*include\s+"nopox-keys\.kdl"/m.test(configText)

    // действующие бинды: config.kdl, поверх — nopox-binds.kdl, поверх — свои
    readonly property var all: {
        const map = {};
        for (const b of configBinds) map[S.comboKey(b.combo)] = Object.assign({}, b);
        for (const b of nopoxBinds) map[S.comboKey(b.combo)] = Object.assign({}, b);
        for (const k in keys) {
            const own = keys[k];
            const base = map[k] ?? null;
            map[k] = {
                combo: own.combo,
                title: own.action === "off" ? "" : (own.title ?? ""),
                hidden: own.action === "off",
                action: own.action === "off" ? "off" : S.actionKdl(own.action),
                source: base ? "changed" : "own",
                off: own.action === "off",
                base
            };
        }
        return Object.values(map).sort((a, b) => a.combo.localeCompare(b.combo));
    }

    function set(newKeys) {
        _prevKeys = keys;
        error = "";
        if (Object.keys(newKeys).length) Settings.set("niri.keys", newKeys);
        else Settings.reset("niri.keys");
    }

    function setKey(combo, action, title) {
        const k = Object.assign({}, keys);
        k[S.comboKey(combo)] = { combo, action, title: title ?? "" };
        set(k);
    }

    // переименование: старое сочетание — отключить (если оно из конфига) или убрать (если своё)
    function replaceKey(oldCombo, combo, action, title) {
        const k = Object.assign({}, keys);
        const oldK = S.comboKey(oldCombo);
        if (oldCombo && oldK !== S.comboKey(combo)) {
            const fromConfig = [...configBinds, ...nopoxBinds].some(b => S.comboKey(b.combo) === oldK);
            if (fromConfig) k[oldK] = { combo: oldCombo, action: "off", title: "" };
            else delete k[oldK];
        }
        k[S.comboKey(combo)] = { combo, action, title: title ?? "" };
        set(k);
    }

    function disable(combo) { setKey(combo, "off", ""); }

    function reset(combo) {
        const k = Object.assign({}, keys);
        delete k[S.comboKey(combo)];
        set(k);
    }

    // для старых установок: в config.kdl ещё нет include "nopox-keys.kdl"
    function ensureIncluded() {
        includer.running = true;
    }

    property string _written: ""

    function writeKeys() {
        if (Settings.greeterMode || !Settings.loaded) return;
        const text = S.keysKdl(keys);
        if (text === _written) return;   // иначе niri перечитывал бы конфиг при любом изменении настроек
        _written = text;
        keysFile.setText(text);
        validate.restart();
    }

    onKeysChanged: writeKeys()

    Connections {
        target: Settings
        function onLoadedChanged() { root.writeKeys(); }
    }

    FileView {
        id: configFile
        path: Settings.greeterMode ? "" : root.dir + "/config.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.configText = text();
            root.configBinds = S.parseBinds(text(), "config");
        }
    }

    FileView {
        id: nopoxFile
        path: Settings.greeterMode ? "" : root.dir + "/nopox-binds.kdl"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.nopoxBinds = S.parseBinds(text(), "nopox")
    }

    FileView {
        id: keysFile
        path: Settings.greeterMode ? "" : root.dir + "/nopox-keys.kdl"
    }

    // niri перечитывает конфиг сам; проверяем, что новый вариант корректен
    Timer {
        id: validate
        interval: 300
        onTriggered: validator.running = true
    }

    Process {
        id: validator
        command: ["niri", "validate", "-c", root.dir + "/config.kdl"]
        stderr: StdioCollector { id: validateErr }
        onExited: code => {
            if (code === 0) {
                root._prevKeys = null;
                return;
            }
            if (root._prevKeys === null) return;
            // в выводе niri — рамки диагностики; берём последнюю строку «× …» и место «╭─[файл:строка]»
            const lines = validateErr.text.split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, ""));
            const what = lines.filter(l => l.includes("×")).map(l => l.split("×").pop().trim()).pop() ?? "ошибка конфига";
            const where = lines.map(l => l.match(/╭─\[([^\]]+)\]/)?.[1]).filter(x => x).pop();
            root.error = "niri не принял бинд — отменено: " + what + (where ? " (" + where + ")" : "");
            const prev = root._prevKeys;
            root._prevKeys = null;
            if (Object.keys(prev).length) Settings.set("niri.keys", prev);
            else Settings.reset("niri.keys");
        }
    }

    Process {
        id: includer
        command: ["sh", "-c", 'grep -q "^include \\"nopox-keys.kdl\\"" "$1/config.kdl" || printf "\\n// свои бинды из окна биндов nopox — последними, чтобы перекрывать остальные\\ninclude \\"nopox-keys.kdl\\"\\n" >> "$1/config.kdl"', "sh", root.dir]
    }

    Process {
        running: !Settings.greeterMode
        command: ["niri", "msg", "action", "--help"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const out = [];
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^  ([a-z0-9-]+)\s*$/);
                    if (m && m[1] !== "help") out.push({ name: m[1], desc: (lines[i + 1] ?? "").trim() });
                }
                root.actions = out;
            }
        }
    }
}
