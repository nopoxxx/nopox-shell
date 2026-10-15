import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/settings.js" as S

// Настройки в стиле menuconfig: разделы слева, параметры справа.
//   ↑↓ выбор, ←→ изменить, ↵ переключить/редактировать, r сброс, tab раздел, esc выход
//   qs ipc call settings toggle
Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle(): void { Settings.open = !Settings.open; }
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
            readonly property var rows: sections[section].rows
            property int cur: 1
            property bool editing: false
            readonly property var row: rows[cur] ?? null

            Component.onCompleted: Settings.refreshOutputs()

            function isItem(i) { return i >= 0 && i < rows.length && !rows[i].header; }

            function move(d) {
                let i = cur + d;
                while (i >= 0 && i < rows.length && !isItem(i)) i += d;
                if (isItem(i)) cur = i;
            }

            function selectSection(i) {
                section = (i + sections.length) % sections.length;
                cur = 0;
                move(1);
            }

            // обои хранят заполнение сами, остальное — в Settings
            function value(r) { return r.key === "wallpaper.fill" ? Wallpaper.fill : Settings.get(r.key); }
            function changed(r) {
                if (r.type === "module") return S.zoneOf(null, r.id) !== r.zone;
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

            function reset(r) {
                if (r.type === "module") {
                    Settings.reset(r.key);
                    selectModule(r.id);
                } else if (r.key === "wallpaper.fill") Wallpaper.setFill(r.def);
                else Settings.reset(r.key);
            }

            function adjust(r, d) {
                if (r.type === "module") {
                    moveModule(r, d);
                } else if (r.type === "bool") {
                    setValue(r, !value(r));
                } else if (r.type === "enum") {
                    const o = r.options;
                    setValue(r, o[(o.indexOf(value(r)) + d + o.length) % o.length]);
                } else if (r.type === "int" || r.type === "float") {
                    const v = Math.min(r.max, Math.max(r.min, value(r) + d * r.step));
                    setValue(r, r.type === "int" ? Math.round(v) : Number(v.toFixed(2)));
                }
            }

            function activate(r) {
                if (r.type === "text") {
                    editing = true;
                    editor.text = value(r);
                    editor.selectAll();
                    editor.forceActiveFocus();
                } else if (r.type === "action") {
                    Settings.open = false;
                    if (r.action === "lock" || r.action === "lockPreview") {
                        Quickshell.execDetached(["qs", "ipc", "call", "lock", r.action === "lock" ? "lock" : "preview"]);
                    } else {
                        Wallpaper.pickerSource = "local";
                        Wallpaper.pickerOpen = true;
                    }
                } else {
                    adjust(r, 1);
                }
            }

            function finishEdit(commit) {
                if (commit && row) setValue(row, editor.text.trim());
                editing = false;
                keys.forceActiveFocus();
            }

            function fmt(r) {
                if (r.type === "module") return "‹ " + r.zone + " ›";
                const v = value(r);
                if (r.type === "bool") return v ? "[x]" : "[ ]";
                if (r.type === "text") return JSON.stringify(v);
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
                if (r.type === "module") return r.zone === "off" ? Theme.gray : Theme.blue;
                if (r.type === "bool") return value(r) ? Theme.accent : Theme.gray;
                if (r.type === "text") return Theme.aqua;
                if (r.key === "shell.accent") return Theme.accent;
                return Theme.fg;
            }

            onCurChanged: list.positionViewAtIndex(cur, ListView.Contain)

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
                width: cell.advanceWidth * 84 + Theme.pad * 2
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
                    T { id: title; text: "[ ~/settings/" + win.sections[win.section].id + "/ ]"; color: Theme.accent; font.bold: true }
                }

                // невидимый приёмник клавиш, пока не редактируем текст
                Item {
                    id: keys
                    focus: true

                    Keys.onPressed: event => {
                        const r = win.row;
                        const k = event.key;
                        const shift = event.modifiers & Qt.ShiftModifier;
                        const isModule = r && r.type === "module";
                        if (isModule && ((shift && k === Qt.Key_Up) || (shift && k === Qt.Key_K))) {
                            win.reorderModule(r, -1);
                        } else if (isModule && ((shift && k === Qt.Key_Down) || (shift && k === Qt.Key_J))) {
                            win.reorderModule(r, 1);
                        } else if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                            Settings.open = false;
                        } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                            win.move(1);
                        } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                            win.move(-1);
                        } else if (k === Qt.Key_Tab) {
                            win.selectSection(win.section + 1);
                        } else if (k === Qt.Key_Backtab) {
                            win.selectSection(win.section - 1);
                        } else if (k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < win.sections.length) {
                            win.selectSection(k - Qt.Key_1);
                        } else if (r && (k === Qt.Key_Right || k === Qt.Key_L)) {
                            win.adjust(r, 1);
                        } else if (r && (k === Qt.Key_Left || k === Qt.Key_H)) {
                            win.adjust(r, -1);
                        } else if (r && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) {
                            win.activate(r);
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.pad

                        // ── разделы ──
                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            // вложенные Layout по умолчанию растягиваются — колонка разделов фиксированная
                            Layout.fillWidth: false
                            Layout.preferredWidth: cell.advanceWidth * 14
                            spacing: 0

                            Repeater {
                                model: win.sections

                                Rectangle {
                                    id: sec

                                    required property var modelData
                                    required property int index
                                    readonly property bool current: index === win.section

                                    Layout.fillWidth: true
                                    implicitHeight: win.lineH
                                    color: current ? Theme.bg1 : "transparent"

                                    T {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (sec.current ? "▌ " : "  ") + (sec.index + 1) + " " + sec.modelData.id + "/"
                                        color: sec.current ? Theme.accent : Theme.blue
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
                                            color: line.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                            font.bold: line.current
                                        }
                                        T {
                                            text: !line.modelData.header && win.changed(line.modelData) ? " *" : ""
                                            color: Theme.accent
                                        }
                                        Item { Layout.fillWidth: true }

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
                                                    if (mouse.button === Qt.RightButton) win.adjust(line.modelData, -1);
                                                    else win.activate(line.modelData);
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: win.cur = line.index
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

                        // подсказка: описание, ключ и значение по умолчанию
                        T {
                            visible: !win.editing
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            color: Theme.gray
                            text: {
                                const r = win.row;
                                if (!r) return "";
                                if (r.type === "module") return r.hint + "  ·  ←→ зона, ⇧↑↓ или K/J — порядок";
                                const def = r.type === "action" ? "" : "  ·  по умолчанию " + JSON.stringify(r.def);
                                return (r.hint ? r.hint + "  ·  " : "") + r.key + def;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Item { Layout.fillWidth: true }
                        T {
                            textFormat: Text.StyledText
                            color: Theme.gray
                            text: (win.editing
                                ? [["↵", "сохранить"], ["esc", "отмена"]]
                                : [["↑↓", "выбор"], ["←→", "изменить"], ["↵", "переключить"], ["r", "сброс"], ["⇥", "раздел"], ["esc", "выход"]])
                                .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                        }
                    }
                }
            }
        }
    }
}
