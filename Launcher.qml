import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy

// Меню в духе omarchy: сначала раздел (apps/, install/, system/ …), потом действие.
// Разделы ведут себя как каталоги: путь в заголовке, Esc или ← — на уровень выше.
//   qs ipc call launcher toggle — корень меню
//   qs ipc call launcher apps   — сразу список программ
Scope {
    id: root

    property bool open: false
    property string startAt: ""
    readonly property int rows: Settings.get("shell.launcher.rows")
    readonly property string home: Quickshell.env("HOME")

    IpcHandler {
        target: "launcher"
        // не `show`: это имя занято подкомандой `qs ipc show`
        function toggle(): void { root.startAt = ""; root.open = !root.open; }
        function apps(): void { root.startAt = "apps"; root.open = !root.open; }
        function open(): void { root.startAt = ""; root.open = true; }
        function close(): void { root.open = false; }
    }

    // ── действия ───────────────────────────────────────────────────

    function shq(s) { return "'" + s.replace(/'/g, "'\\''") + "'"; }

    // команда в плавающем окне терминала (Term); с hold вывод остаётся на экране
    function term(cmd, hold = true) {
        Term.float(["bash", "-c", cmd], { hold });
    }

    function spawn(argv) { Quickshell.execDetached(argv); }

    function edit(path) { term("vim " + shq(path), false); }

    function fillDesc(mode, text) {
        return (Wallpaper.fill === mode ? "● " : "  ") + text;
    }

    function openPicker(source) {
        Wallpaper.pickerSource = source;
        Wallpaper.pickerOpen = true;
    }

    function launchApp(entry) {
        if (entry.runInTerminal)
            Term.open(entry.command);
        else
            entry.execute();
    }

    // ── дерево меню ────────────────────────────────────────────────
    // узел: { label, desc, icon, children | provider | run }

    readonly property var icons: ({
        apps: String.fromCodePoint(0xF003B),
        setup: String.fromCodePoint(0xF0493),
        style: String.fromCodePoint(0xF03D8),
        install: String.fromCodePoint(0xF03D7),
        remove: String.fromCodePoint(0xF01B4),
        update: String.fromCodePoint(0xF06B0),
        system: String.fromCodePoint(0xF0425),
        about: String.fromCodePoint(0xF02FD)
    })

    readonly property var menu: ({
        label: "~",
        children: [
            { label: "apps", icon: icons.apps, desc: "запуск программ", provider: "apps" },
            { label: "setup", icon: icons.setup, desc: "настройки, сеть, звук, конфиги", children: [
                { label: "settings", desc: "настройки niri и shell (Mod+S)", run: () => Settings.open = true },
                { label: "displays", desc: "мониторы: режим, масштаб, поворот, расположение", run: () => spawn(["qs", "ipc", "call", "displays", "toggle"]) },
                { label: "wifi", desc: "nmtui", run: () => term("nmtui", false) },
                { label: "audio", desc: "pavucontrol", run: () => spawn(["pavucontrol"]) },
                { label: "binds", desc: "изменить бинды niri и nopox", run: () => spawn(["qs", "ipc", "call", "binds", "toggle"]) },
                { label: "keybindings", desc: "подсказка по клавишам niri", run: () => spawn(["niri", "msg", "action", "show-hotkey-overlay"]) },
                { label: "config", desc: "редактировать конфиги", children: [
                    { label: "niri", desc: "~/.config/niri/config.kdl", run: () => edit(home + "/.config/niri/config.kdl") },
                    { label: "quickshell", desc: "~/.config/quickshell/", run: () => edit(home + "/.config/quickshell") },
                    { label: "terminal", desc: "конфиг терминала (" + Term.name + ")", run: () => edit(home + ({
                        kitty: "/.config/kitty/kitty.conf", alacritty: "/.config/alacritty/alacritty.toml",
                        ghostty: "/.config/ghostty/config", foot: "/.config/foot/foot.ini" })[Term.name]) }
                ] },
                { label: "restart shell", desc: "перезапустить quickshell", run: () => spawn(["sh", "-c", "pkill -x qs; sleep 0.3; niri msg action spawn -- qs"]) },
                { label: "shell update", desc: "обновить nopox-shell с GitHub (git pull)", run: () => ShellUpdate.behind > 0 ? ShellUpdate.update() : ShellUpdate.check(true) },
                { label: "greeter update", desc: "переустановить greeter из текущего shell (sudo)", run: () => ShellUpdate.updateGreeter() }
            ] },
            { label: "style", icon: icons.style, desc: "обои", children: [
                { label: "wallpaper", desc: "локальная коллекция", run: () => openPicker("local") },
                { label: "wallhaven", desc: "поиск на wallhaven.cc", run: () => openPicker("wallhaven") },
                { label: "fill", desc: "заполнение обоев: " + Wallpaper.fill, children: [
                    { label: "fill", desc: fillDesc("fill", "заполнить экран, лишнее обрезать"), run: () => Wallpaper.setFill("fill") },
                    { label: "fit", desc: fillDesc("fit", "вписать целиком, по краям полосы"), run: () => Wallpaper.setFill("fit") },
                    { label: "stretch", desc: fillDesc("stretch", "растянуть без сохранения пропорций"), run: () => Wallpaper.setFill("stretch") }
                ] }
            ] },
            { label: "install", icon: icons.install, desc: "установить пакеты", children: [
                { label: "package", desc: "из репозиториев: arch, chaotic-aur", provider: "repo" },
                { label: "aur", desc: "поиск в AUR через paru", provider: "aur" }
            ] },
            { label: "remove", icon: icons.remove, desc: "удалить пакеты", provider: "installed" },
            { label: "update", icon: icons.update, desc: "paru -Syu", run: () => term("paru -Syu") },
            { label: "system", icon: icons.system, desc: "питание и сессия", children: [
                { label: "lock", desc: "заблокировать экран (Super+Alt+L)", run: () => spawn(["qs", "ipc", "call", "lock", "lock"]) },
                { label: "suspend", desc: "заблокировать и уснуть", run: () => spawn(["sh", "-c", "qs ipc call lock lock; sleep 0.5; systemctl suspend"]) },
                { label: "reboot", desc: "перезагрузка", run: () => spawn(["systemctl", "reboot"]) },
                { label: "poweroff", desc: "выключение", run: () => spawn(["systemctl", "poweroff"]) },
                { label: "logout", desc: "выйти из niri", run: () => spawn(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
            ] },
            { label: "about", icon: icons.about, desc: "fastfetch", run: () => term("fastfetch") }
        ]
    })

    // ── источники динамических списков ─────────────────────────────

    property var cache: ({})

    onOpenChanged: if (open) cache = {}   // после install/remove списки устаревают

    function providerItems(name, query) {
        if (name === "apps")
            return DesktopEntries.applications.values
                .filter(e => !e.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))
                .map(e => ({
                    label: e.name,
                    desc: e.genericName,
                    search: [e.genericName, e.comment, ...e.keywords].join(" "),
                    run: () => launchApp(e)
                }));
        if (name === "aur")
            return query ? [{ label: "paru " + query, desc: "найти и установить из AUR", run: () => term("paru " + shq(query)) }] : [];
        return cache[name] ?? null; // null — ещё загружается
    }

    function load(name) {
        if (!["repo", "installed"].includes(name) || cache[name] || pkgProc.running) return;
        pkgProc.target = name;
        pkgProc.command = name === "repo" ? ["pacman", "-Sl"] : ["pacman", "-Qe"];
        pkgProc.running = true;
    }

    Process {
        id: pkgProc

        property string target

        stdout: StdioCollector {
            onStreamFinished: {
                const items = [];
                for (const line of this.text.split("\n")) {
                    const f = line.split(" ");
                    if (pkgProc.target === "repo" && f.length >= 3) {
                        const [repo, name, ver] = f;
                        items.push({ label: name, desc: repo + " " + ver + (f[3] ? "  [installed]" : ""), run: () => root.term("paru -S " + name) });
                    } else if (pkgProc.target === "installed" && f.length >= 2) {
                        const [name, ver] = f;
                        items.push({ label: name, desc: ver, run: () => root.term("sudo pacman -Rns " + name) });
                    }
                }
                root.cache = Object.assign({}, root.cache, { [pkgProc.target]: items });
            }
        }
    }

    // ── окно ───────────────────────────────────────────────────────

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "nopox-launcher"

            property var stack: []
            readonly property var node: stack[stack.length - 1] ?? null
            readonly property string path: "~/" + stack.slice(1).map(n => n.label + "/").join("")
            readonly property var items: node ? (node.children ?? root.providerItems(node.provider, input.text.trim())) : []

            readonly property var results: {
                if (!items) return [];
                const q = input.text.trim();
                if (!q || node.provider === "aur") return items.map(it => ({ item: it, pos: [] }));
                const out = [];
                for (const it of items) {
                    const byName = Fuzzy.match(q, it.label);
                    const byExtra = Fuzzy.match(q, it.search ?? it.desc ?? "");
                    const nameScore = byName ? byName.score + 5 : -Infinity;
                    const extraScore = byExtra ? byExtra.score * 0.8 : -Infinity;
                    if (byName && nameScore >= extraScore)
                        out.push({ item: it, pos: byName.pos, score: nameScore });
                    else if (byExtra)
                        out.push({ item: it, pos: [], score: extraScore });
                }
                // при равном счёте — более короткое имя выше (neovim раньше neovim-qt)
                return out.sort((a, b) => (b.score - a.score) || (a.item.label.length - b.item.label.length));
            }

            Component.onCompleted: {
                const s = [root.menu];
                const start = root.menu.children.find(c => c.label === root.startAt);
                if (start) s.push(start);
                stack = s;
            }

            onNodeChanged: if (node?.provider) root.load(node.provider)
            onResultsChanged: list.currentIndex = 0

            function enter(it) {
                if (it.children || it.provider) {
                    stack = stack.concat([it]);
                    input.text = "";
                } else {
                    it.run();
                    root.open = false;
                }
            }

            function back() {
                if (stack.length > 1) {
                    stack = stack.slice(0, -1);
                    input.text = "";
                } else {
                    root.open = false;
                }
            }

            property point lastMouse
            property bool lastMouseSet: false

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            // клик мимо окна закрывает меню
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: cell.advanceWidth * 64 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                // заголовок на линии рамки: ┌─[ ~/install/ ]────
                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ " + win.path + " ]"; color: Theme.accent; font.bold: true }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T { text: "❯ "; color: Theme.accent; font.bold: true }

                        TextInput {
                            id: input

                            Layout.fillWidth: true
                            focus: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            selectionColor: Theme.bg2
                            renderType: Text.NativeRendering

                            cursorDelegate: Rectangle {
                                id: caret
                                width: cell.advanceWidth
                                color: Theme.fg
                                Timer {
                                    interval: 530
                                    running: true
                                    repeat: true
                                    onTriggered: caret.opacity = caret.opacity > 0 ? 0 : 1
                                }
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier;
                                const empty = input.text.length === 0;
                                const cur = win.results[list.currentIndex];
                                if (event.key === Qt.Key_Escape) {
                                    win.back();
                                } else if (empty && (event.key === Qt.Key_Backspace || event.key === Qt.Key_Left) && win.stack.length > 1) {
                                    win.back();
                                } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                    list.incrementCurrentIndex();
                                } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                    list.decrementCurrentIndex();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (cur) win.enter(cur.item);
                                } else if (event.key === Qt.Key_Right && cur && (cur.item.children || cur.item.provider)) {
                                    win.enter(cur.item);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        T {
                            text: win.items === null ? "загрузка…" : win.results.length + "/" + win.items.length
                            color: Theme.gray
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        implicitHeight: cell.height * 1.25 * root.rows
                        clip: true
                        model: win.results
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property var item: modelData.item
                            readonly property bool isDir: !!(item.children || item.provider)
                            readonly property bool current: ListView.isCurrentItem

                            width: list.width
                            height: cell.height * 1.25
                            color: current ? Theme.bg1 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                T {
                                    text: row.current ? "▌ " : "  "
                                    color: Theme.accent
                                }
                                T {
                                    visible: !!row.item.icon
                                    text: (row.item.icon ?? "") + " "
                                    color: row.current ? Theme.accent : Theme.gray
                                }
                                // разделы — как каталоги в ls: синие и со слешем
                                T {
                                    textFormat: Text.StyledText
                                    text: Fuzzy.highlight(row.item.label, row.modelData.pos, Theme.orange) + (row.isDir ? "/" : "")
                                    color: row.isDir ? Theme.blue : row.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                    font.bold: row.current
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.item.desc ? "  " + row.item.desc : ""
                                    color: Theme.gray
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                // Qt шлёт hover-события и когда строка проезжает под неподвижным курсором,
                                // поэтому выделяем только при реальном сдвиге мыши
                                onPositionChanged: mouse => {
                                    const p = mapToGlobal(mouse.x, mouse.y);
                                    if (win.lastMouseSet && (p.x !== win.lastMouse.x || p.y !== win.lastMouse.y))
                                        list.currentIndex = row.index;
                                    win.lastMouse = p;
                                    win.lastMouseSet = true;
                                }
                                onClicked: win.enter(row.item)
                            }
                        }
                    }
                }
            }
        }
    }
}
