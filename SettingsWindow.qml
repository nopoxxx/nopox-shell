import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/settings.js" as S

// Настройки в стиле menuconfig: разделы слева, параметры справа, поиск по всем разделам.
//   ↑↓ выбор, ←→ изменить, ↵ переключить/открыть, r сброс, / поиск, tab раздел, esc выход
//   qs ipc call settings toggle
//   qs ipc call settings open <раздел>   — look, windows, input, bar, notify, lock, system; "" — последний
Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle(): void { Settings.open = !Settings.open; }
        function open(section: string): void { Settings.show(section); }
    }

    LazyLoader {
        active: Settings.open

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "nopox-settings"

            readonly property var sections: S.sections(Settings.outputs, Settings.get("shell.bar.layout"))
            property int section: 0
            readonly property string query: search.text.trim()
            readonly property var rows: query ? S.searchRows(sections, query) : sections[section].rows
            property int cur: 1
            property bool editing: false
            property bool capturing: false   // строка combo ждёт нажатия сочетания
            // черновик: ←→, Space, клик и r меняют только его, применяет ↵, Esc или уход со строки — отменяют
            property var draft: null         // { key, value }
            readonly property var row: rows[cur] ?? null

            Component.onCompleted: {
                Settings.refreshOutputs();
                selectSection(Math.max(0, sections.findIndex(s => s.id === Settings.page)));
            }

            onQueryChanged: {
                cur = 0;
                move(1);
            }

            function isItem(i) { return i >= 0 && i < rows.length && !rows[i].header; }

            function move(d) {
                let i = cur + d;
                while (i >= 0 && i < rows.length && !isItem(i)) i += d;
                if (isItem(i)) cur = i;
            }

            function selectSection(i) {
                search.text = "";
                section = (i + sections.length) % sections.length;
                Settings.page = sections[section].id;
                cur = 0;
                move(1);
            }

            // ── действия (строки type: "action") ──

            function runAction(name) {
                Settings.open = false;
                // из этих окон Esc возвращает сюда же
                Settings.returnHere = ["picker", "wallhaven", "binds", "displays", "lockPreview"].includes(name);
                const ipc = (...args) => Quickshell.execDetached(["qs", "ipc", "call", ...args]);
                switch (name) {
                case "picker": Wallpaper.pickerSource = "local"; Wallpaper.pickerOpen = true; break;
                case "wallhaven": Wallpaper.pickerSource = "wallhaven"; Wallpaper.pickerOpen = true; break;
                case "binds": ipc("binds", "toggle"); break;
                case "hotkeys": Niri.action("show-hotkey-overlay"); break;
                case "displays": ipc("displays", "toggle"); break;
                case "lock": ipc("lock", "lock"); break;
                case "lockPreview": ipc("lock", "preview"); break;
                case "wifi": Term.float(["nmtui"]); break;
                case "audio": Quickshell.execDetached(["pavucontrol"]); break;
                case "editNiri": Term.edit(Quickshell.env("HOME") + "/.config/niri/config.kdl"); break;
                case "editShell": Term.edit(Quickshell.shellDir); break;
                case "editTerminal": Term.edit(Term.configPath); break;
                case "shellUpdate": if (ShellUpdate.behind > 0) ShellUpdate.update(); else ShellUpdate.check(true); break;
                case "restartShell": ShellUpdate.restartShell(); break;
                case "greeterUpdate": ShellUpdate.updateGreeter(); break;
                default: console.warn("settings: неизвестное действие", name);
                }
            }

            // ── значения ──

            // обои хранят заполнение сами, остальное — в Settings
            function value(r) { return r.key === "wallpaper.fill" ? Wallpaper.fill : Settings.get(r.key); }
            function changed(r) {
                if (r.type === "module") return S.zoneOf(null, r.id) !== r.zone;
                if (r.type === "action") return false;
                return r.key === "wallpaper.fill" ? Wallpaper.fill !== r.def : !Settings.isDefault(r.key);
            }

            // строки модулей панели пересоздаются при каждом изменении раскладки — выделение идёт за модулем
            function selectModule(id) {
                const i = rows.findIndex(x => x.type === "module" && x.id === id);
                if (i >= 0) cur = i;
            }

            function moveModule(r, d) {
                Settings.set("shell.bar.layout", S.moveModule(Settings.get("shell.bar.layout"), r.id, d));
                selectModule(r.id);
            }

            function reorderModule(r, d) {
                const l = S.reorderModule(Settings.get("shell.bar.layout"), r.id, d);
                if (!l) return;
                Settings.set("shell.bar.layout", l);
                selectModule(r.id);
            }

            function setValue(r, v) {
                if (r.key === "wallpaper.fill") Wallpaper.setFill(v);
                else Settings.set(r.key, v);
            }

            // ── черновик ──
            function drafted(r) { return !!draft && !!r && draft.key === r.key; }
            function shown(r) { return drafted(r) ? draft.value : value(r); }

            function propose(r, v) {
                // вернулись к текущему значению — черновика нет
                draft = v === value(r) ? null : { key: r.key, value: v };
            }

            function apply() {
                if (!draft || !row || draft.key !== row.key) return;
                setValue(row, draft.value);
                draft = null;
            }

            function reset(r) {
                if (r.type === "action") return;
                if (r.type === "module") {
                    Settings.reset(r.key);
                    selectModule(r.id);
                } else if (r.type === "combo" || r.type === "text") {
                    Settings.reset(r.key);
                } else {
                    propose(r, r.def);   // по умолчанию — тоже через ↵
                }
            }

            function adjust(r, d) {
                const v = shown(r);
                if (r.type === "module") {
                    moveModule(r, d);
                } else if (r.type === "bool") {
                    propose(r, !v);
                } else if (r.type === "enum") {
                    const o = r.options;
                    propose(r, o[(o.indexOf(v) + d + o.length) % o.length]);
                } else if (r.type === "int" || r.type === "float") {
                    const n = Math.min(r.max, Math.max(r.min, v + d * r.step));
                    propose(r, r.type === "int" ? Math.round(n) : Number(n.toFixed(2)));
                }
            }

            function activate(r) {
                if (drafted(r)) {
                    apply();
                } else if (r.type === "combo") {
                    capturing = true;
                } else if (r.type === "text") {
                    editing = true;
                    editor.text = value(r);
                    editor.selectAll();
                    editor.forceActiveFocus();
                } else if (r.type === "action") {
                    runAction(r.action);
                } else if (r.type === "module") {
                    adjust(r, 1);
                }
                // значения (bool/enum/int/float) без черновика: ↵ ничего не меняет — выбирают ←→, Space или клик
            }

            // ⇥ в захвате: сочетание, занятое niri (Mod+D и т.п.), не нажать — niri перехватит его раньше окна
            function editComboAsText(r) {
                capturing = false;
                editing = true;
                editor.text = value(r);
                editor.selectAll();
                editor.forceActiveFocus();
            }

            function finishEdit(commit) {
                if (commit && row) setValue(row, row.type === "combo" ? editor.text.trim().replace(/\s+/g, "") : editor.text.trim());
                editing = false;
                keys.forceActiveFocus();
            }

            function startSearch() {
                search.forceActiveFocus();
                search.selectAll();
            }

            function endSearch(keep) {
                if (!keep) search.text = "";
                keys.forceActiveFocus();
            }

            function fmt(r, v) {
                if (r.type === "module") return "‹ " + r.zone + " ›";
                if (v === undefined) v = shown(r);
                if (r.type === "bool") return v ? "[x]" : "[ ]";
                if (r.type === "text") return JSON.stringify(v);
                if (r.type === "combo") return capturing && r === row ? "нажмите сочетание…" : v ? "[" + v + "]" : "—";
                if (r.type === "action") return "↵";
                if (r.type === "float") {
                    const decimals = String(r.step).split(".")[1]?.length ?? 0;
                    return "‹ " + Number(v).toFixed(decimals) + " ›";
                }
                // значения с пробелами по краям (разделители) — в кавычках, иначе их не видно
                if (typeof v === "string" && v !== v.trim()) return "‹ " + JSON.stringify(v) + " ›";
                return "‹ " + v + " ›";
            }

            function valueColor(r) {
                if (drafted(r)) return Theme.accent;
                if (r.type === "module") return r.zone === "off" ? Theme.gray : Theme.blue;
                if (r.type === "bool") return value(r) ? Theme.accent : Theme.gray;
                if (r.type === "text") return Theme.aqua;
                if (r.type === "action") return Theme.accent;
                if (r.type === "combo") return capturing && r === row ? Theme.accent : value(r) ? Theme.blue : Theme.gray;
                if (r.key === "shell.accent") return Theme.accent;
                return Theme.fg;
            }

            function hint(r) {
                if (!r) return "";
                if (r.type === "module") return r.hint + "  ·  ←→ зона, ⇧↑↓ или K/J — порядок";
                const file = S.niriFileOf(r.key);
                // файл первым: подсказка длинная и обрезается справа
                const parts = [file ? "niri/nopox/" + file : "", r.hint ?? ""];
                if (r.type === "combo" && value(r)) {
                    if (!S.COMBO_RE.test(value(r))) parts.unshift("не похоже на сочетание (Mod+Shift+M) — бинд не создан");
                    const other = Binds.conflict(value(r), r.action);
                    if (other) parts.unshift("занято: " + other.action + " — конфликт");
                }
                if (r.type !== "action") parts.push(r.key + "  ·  по умолчанию " + JSON.stringify(r.def));
                return parts.filter(x => x).join("  ·  ");
            }

            onCurChanged: {
                capturing = false;
                draft = null;   // ушли со строки — не подтверждено, значит не применяем
                list.positionViewAtIndex(cur, ListView.Contain);
            }

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            readonly property real lineH: cell.height * 1.3

            MouseArea {
                anchors.fill: parent
                onClicked: Settings.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: cell.advanceWidth * 96 + Theme.pad * 2
                height: col.implicitHeight + Theme.pad * 2
                color: Theme.bg
                border.color: Theme.accent
                border.width: 2

                MouseArea { anchors.fill: parent }

                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T {
                        id: title
                        text: win.query ? "[ ~/settings/?" + win.query + " ]" : "[ ~/settings/" + win.sections[win.section].id + "/ ]"
                        color: Theme.accent
                        font.bold: true
                    }
                }

                // невидимый приёмник клавиш, пока не редактируем текст и не ищем
                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const r = win.row;
                        const k = event.key;
                        // захват сочетания: Esc — отмена, ⌫/Delete — убрать бинд, ⇥ — ввести текстом
                        if (win.capturing) {
                            event.accepted = true;
                            const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier));
                            if (plain && k === Qt.Key_Escape) win.capturing = false;
                            else if (plain && (k === Qt.Key_Backspace || k === Qt.Key_Delete)) { win.reset(r); win.capturing = false; }
                            else if (plain && k === Qt.Key_Tab) win.editComboAsText(r);
                            else {
                                const combo = Binds.comboOf(event);
                                if (!combo) return;   // пока зажат только модификатор
                                win.setValue(r, combo);
                                win.capturing = false;
                            }
                            return;
                        }
                        if (win.draft && (k === Qt.Key_Escape || k === Qt.Key_Q)) {
                            win.draft = null;
                            event.accepted = true;
                            return;
                        }
                        const shift = event.modifiers & Qt.ShiftModifier;
                        const isModule = r && r.type === "module";
                        if (isModule && ((shift && k === Qt.Key_Up) || (shift && k === Qt.Key_K))) {
                            win.reorderModule(r, -1);
                        } else if (isModule && ((shift && k === Qt.Key_Down) || (shift && k === Qt.Key_J))) {
                            win.reorderModule(r, 1);
                        } else if (k === Qt.Key_Slash) {
                            win.startSearch();
                        } else if (k === Qt.Key_Escape && win.query) {
                            win.endSearch(false);
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            Settings.open = false;
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.move(1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            win.selectSection(win.query ? win.section : win.section + 1);
                        } else if (k === Qt.Key_Backtab) {
                            win.selectSection(win.query ? win.section : win.section - 1);
                        } else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < win.sections.length) {
                            win.selectSection(k - Qt.Key_1);
                        } else if (r && (k === Qt.Key_Right || k === Qt.Key_L)) {
                            win.adjust(r, 1);
                        } else if (r && (k === Qt.Key_Left || k === Qt.Key_H)) {
                            win.adjust(r, -1);
                        } else if (r && (k === Qt.Key_Return || k === Qt.Key_Enter)) {
                            win.activate(r);
                        } else if (r && k === Qt.Key_Space) {
                            // Space — следующее значение в черновик; у текста, сочетаний и действий — как ↵
                            if (["bool", "enum", "int", "float"].includes(r.type)) win.adjust(r, 1);
                            else win.activate(r);
                        } else if (r && k === Qt.Key_R) {
                            win.reset(r);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    // ── поиск ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T { text: "/ "; color: search.activeFocus ? Theme.accent : Theme.gray; font.bold: true }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: search.implicitHeight

                            TextInput {
                                id: search

                                anchors.fill: parent
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                color: Theme.fg
                                selectionColor: Theme.bg2
                                renderType: Text.NativeRendering

                                Keys.onPressed: event => {
                                    const k = event.key;
                                    if (k === Qt.Key_Escape) win.endSearch(false);
                                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.endSearch(true);
                                    else if (k === Qt.Key_Down) win.move(1);
                                    else if (k === Qt.Key_Up) win.move(-1);
                                    else return;
                                    event.accepted = true;
                                }
                            }

                            T {
                                visible: search.text === ""
                                text: "поиск по всем настройкам"
                                color: Theme.bg2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: win.startSearch()
                            }
                        }

                        T {
                            visible: win.query !== ""
                            text: win.rows.filter(r => !r.header).length + " найдено"
                            color: Theme.gray
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.pad

                        // ── разделы ──
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            // вложенные Layout по умолчанию растягиваются — колонка разделов фиксированная
                            Layout.fillWidth: false
                            Layout.preferredWidth: cell.advanceWidth * 24
                            spacing: 0

                            Repeater {
                                model: win.sections

                                Rectangle {
                                    id: sec

                                    required property var modelData
                                    required property int index
                                    readonly property bool current: index === win.section && !win.query

                                    Layout.fillWidth: true
                                    implicitHeight: win.lineH
                                    color: current ? Theme.bg1 : "transparent"

                                    T {
                                        anchors.verticalCenter: parent.verticalCenter
                                        textFormat: Text.StyledText
                                        text: `<font color="${Theme.accent}">${sec.current ? "▌ " : "&nbsp;&nbsp;"}</font>`
                                            + `<font color="${Theme.gray}">${sec.index + 1} </font>`
                                            + `<font color="${sec.current ? Theme.accent : Theme.blue}">${sec.modelData.id}/</font>`
                                            + `<font color="${Theme.gray}"> ${sec.modelData.title}</font>`
                                        font.bold: sec.current
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: win.selectSection(sec.index)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            implicitWidth: 1
                            color: Theme.bg2
                        }

                        // ── параметры ──
                        ListView {
                            id: list

                            Layout.fillWidth: true
                            implicitHeight: win.lineH * 20
                            clip: true
                            model: win.rows
                            boundsBehavior: Flickable.StopAtBounds

                            T {
                                anchors.centerIn: parent
                                visible: win.query !== "" && win.rows.length === 0
                                text: "ничего не найдено"
                                color: Theme.gray
                            }

                            delegate: Item {
                                id: line

                                required property var modelData
                                required property int index
                                readonly property bool current: index === win.cur

                                width: list.width
                                height: win.lineH

                                // заголовок группы: ── клавиатура ─────────
                                T {
                                    visible: !!line.modelData.header
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "── " + (line.modelData.header ?? "") + " " + "─".repeat(Math.max(0, 60 - (line.modelData.header ?? "").length))
                                    color: Theme.gray
                                    clip: true
                                    width: parent.width
                                }

                                Rectangle {
                                    visible: !line.modelData.header
                                    anchors.fill: parent
                                    color: line.current ? Theme.bg1 : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.rightMargin: Theme.pad
                                        spacing: 0

                                        T { text: line.current ? "▌ " : "  "; color: Theme.accent }
                                        T {
                                            text: line.modelData.label ?? ""
                                            color: line.modelData.type === "action" ? Theme.blue
                                                : line.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                            font.bold: line.current
                                        }
                                        T {
                                            text: !line.modelData.header && win.changed(line.modelData) ? " *" : ""
                                            color: Theme.accent
                                        }
                                        Item { Layout.fillWidth: true }

                                        // черновик: «было →» серым перед новым значением
                                        T {
                                            visible: win.drafted(line.modelData) && line.current
                                            text: win.fmt(line.modelData, win.value(line.modelData)).replace(/^‹ | ›$/g, "") + " → "
                                            color: Theme.gray
                                        }
                                        T {
                                            visible: !(win.editing && line.current)
                                            text: line.modelData.header ? "" : win.fmt(line.modelData)
                                            color: line.modelData.header ? Theme.fg : win.valueColor(line.modelData)
                                            font.bold: line.current

                                            MouseArea {
                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                onClicked: mouse => {
                                                    win.cur = line.index;
                                                    const r = line.modelData;
                                                    // значения — в черновик (кнопка [↵] рядом применяет), остальное — как ↵
                                                    if (["bool", "enum", "int", "float"].includes(r.type))
                                                        win.adjust(r, mouse.button === Qt.RightButton ? -1 : 1);
                                                    else if (mouse.button === Qt.RightButton) win.adjust(r, -1);
                                                    else win.activate(r);
                                                }
                                            }
                                        }
                                        T {
                                            visible: win.drafted(line.modelData) && line.current
                                            text: "  [↵]"
                                            color: Theme.accent
                                            font.bold: true
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.apply() }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: win.cur = line.index
                                        onDoubleClicked: if (line.modelData.type === "action") win.activate(line.modelData)
                                    }
                                }
                            }
                        }
                    }

                    // поле редактирования текста — появляется вместо подсказки
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.bg2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T {
                            text: win.editing ? "❯ " : "  "
                            color: Theme.accent
                            font.bold: true
                        }

                        TextInput {
                            id: editor

                            visible: win.editing
                            Layout.fillWidth: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            selectionColor: Theme.bg2
                            renderType: Text.NativeRendering

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) win.finishEdit(true);
                                else if (event.key === Qt.Key_Escape) win.finishEdit(false);
                                else return;
                                event.accepted = true;
                            }
                        }

                        // подсказка: файл niri, описание, ключ и значение по умолчанию
                        T {
                            visible: !win.editing
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            color: Theme.gray
                            text: win.hint(win.row)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Item { Layout.fillWidth: true }
                        T {
                            textFormat: Text.StyledText
                            color: Theme.gray
                            text: (win.draft
                                ? [["↵", "применить"], ["esc", "отмена"], ["←→", "значение"], ["r", "по умолчанию"]]
                                : win.capturing
                                ? [["…", "нажмите сочетание"], ["⇥", "ввести текстом"], ["⌫", "убрать"], ["esc", "отмена"]]
                                : win.editing
                                ? [["↵", "сохранить"], ["esc", "отмена"]]
                                : search.activeFocus
                                ? [["↑↓", "выбор"], ["↵", "к результатам"], ["esc", "сбросить"]]
                                : [["↑↓", "выбор"], ["←→", "изменить"], ["↵", "открыть"], ["r", "сброс"], ["/", "поиск"], ["⇥", "раздел"], ["esc", win.query ? "сбросить поиск" : "выход"]])
                                .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                        }
                    }
                }
            }
        }
    }
}
