import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy
import "services/settings.js" as S

// Бинды niri: все действующие сочетания с поиском, правка, добавление, отключение.
//   ↵ изменить   ^a добавить   ^d отключить   ^r вернуть исходный   esc выход
// В редакторе сочетание можно нажать (если niri его не перехватывает) или ввести текстом.
//   qs ipc call binds toggle
Scope {
    id: root

    property bool open: false

    onOpenChanged: if (!open) Settings.back()

    IpcHandler {
        target: "binds"
        function toggle(): void { root.open = !root.open; }
    }

    // Qt-клавиша → имя клавиши niri (xkb keysym); символы с Shift — обратно к базовой клавише
    function keyName(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35) return "F" + (key - Qt.Key_F1 + 1);
        const map = {
            [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Space]: "Space", [Qt.Key_Tab]: "Tab",
            [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
            [Qt.Key_Escape]: "Escape", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up",
            [Qt.Key_Down]: "Down", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Page_Up",
            [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Insert]: "Insert", [Qt.Key_Print]: "Print",
            [Qt.Key_Minus]: "Minus", [Qt.Key_Underscore]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_Plus]: "Equal",
            [Qt.Key_Comma]: "Comma", [Qt.Key_Less]: "Comma", [Qt.Key_Period]: "Period", [Qt.Key_Greater]: "Period",
            [Qt.Key_Slash]: "Slash", [Qt.Key_Question]: "Slash", [Qt.Key_Backslash]: "Backslash", [Qt.Key_Bar]: "Backslash",
            [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Colon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe",
            [Qt.Key_QuoteDbl]: "Apostrophe", [Qt.Key_BracketLeft]: "BracketLeft", [Qt.Key_BraceLeft]: "BracketLeft",
            [Qt.Key_BracketRight]: "BracketRight", [Qt.Key_BraceRight]: "BracketRight", [Qt.Key_QuoteLeft]: "Grave",
            [Qt.Key_AsciiTilde]: "Grave", [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3",
            [Qt.Key_Dollar]: "4", [Qt.Key_Percent]: "5", [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7",
            [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MediaPlay]: "XF86AudioPlay",
            [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev"
        };
        return map[key] ?? "";
    }

    // готовые действия nopox — в подсказках первыми
    readonly property var presets: [
        { name: 'spawn "qs" "ipc" "call" "launcher" "toggle"', desc: "nopox: меню" },
        { name: 'spawn "qs" "ipc" "call" "launcher" "apps"', desc: "nopox: программы" },
        { name: 'spawn "qs" "ipc" "call" "settings" "toggle"', desc: "nopox: настройки" },
        { name: 'spawn "qs" "ipc" "call" "wallpaper" "picker"', desc: "nopox: обои" },
        { name: 'spawn "qs" "ipc" "call" "lock" "lock"', desc: "nopox: блокировка" },
        { name: 'spawn "qs" "ipc" "call" "notify" "dnd"', desc: "nopox: не беспокоить" },
        { name: 'spawn "qs" "ipc" "call" "displays" "toggle"', desc: "nopox: мониторы" },
        { name: "spawn kitty", desc: "запустить программу: spawn <команда> [аргументы]" },
        { name: "off", desc: "отключить сочетание" }
    ]

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
            WlrLayershell.namespace: "nopox-binds"

            readonly property int rows: 14

            // ── список ──
            readonly property var results: {
                const q = search.text.trim();
                const all = Binds.all;
                if (!q) return all.map(b => ({ b, pos: [] }));
                const out = [];
                for (const b of all) {
                    const byCombo = Fuzzy.match(q, b.combo);
                    const byText = Fuzzy.match(q, (b.title || "") + " " + b.action);
                    const score = Math.max(byCombo ? byCombo.score + 5 : -1e9, byText ? byText.score : -1e9);
                    if (score > -1e9) out.push({ b, pos: byCombo ? byCombo.pos : [], score });
                }
                return out.sort((a, b) => b.score - a.score);
            }
            // бинды читаются асинхронно — сначала список пуст и currentIndex = -1
            onResultsChanged: list.currentIndex = Math.max(0, Math.min(list.currentIndex, results.length - 1))

            readonly property var cur: results[list.currentIndex]?.b ?? null

            // ── редактор ──
            property bool editing: false
            property string origCombo: ""     // "" — новый бинд
            property int field: 0             // 0 сочетание, 1 действие, 2 подпись
            property int sugIndex: -1

            readonly property var conflict: {
                if (!editing) return null;
                const k = S.comboKey(comboField.text);
                if (!comboField.text.trim() || k === S.comboKey(origCombo)) return null;
                return Binds.all.find(b => S.comboKey(b.combo) === k && !b.off) ?? null;
            }

            readonly property var suggestions: {
                if (!editing || field !== 1) return [];
                const q = actionField.text.trim().split(/\s+/)[0] ?? "";
                const all = root.presets.concat(Binds.actions);
                if (!q) return all.slice(0, 6);
                return all.map(a => ({ a, m: Fuzzy.match(q, a.name + " " + a.desc) }))
                    .filter(x => x.m).sort((x, y) => y.m.score - x.m.score).slice(0, 6).map(x => x.a);
            }

            function startEdit(b) {
                origCombo = b ? b.combo : "";
                comboField.text = b ? b.combo : "";
                actionField.text = b ? (b.off ? "off" : b.action) : "";
                titleField.text = b ? b.title : "";
                field = b ? 1 : 0;
                sugIndex = -1;
                editing = true;
                focusField();
            }

            function focusField() {
                const input = [comboField, actionField, titleField][field].input;
                input.forceActiveFocus();
                input.selectAll();   // ввод заменяет текст целиком, как в форме
            }

            function save() {
                const combo = comboField.text.trim(), action = actionField.text.trim();
                if (!combo || !action) return;
                Binds.replaceKey(origCombo, combo, action, titleField.text.trim());
                editing = false;
                search.forceActiveFocus();
            }

            function cancel() {
                editing = false;
                search.forceActiveFocus();
            }

            // общие клавиши полей редактора
            function editorKeys(event) {
                const k = event.key;
                if (k === Qt.Key_Escape) cancel();
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) save();
                else if (k === Qt.Key_Tab) { field = (field + 1) % 3; focusField(); }
                else if (k === Qt.Key_Backtab) { field = (field + 2) % 3; focusField(); }
                else return false;
                event.accepted = true;
                return true;
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
                onClicked: root.open = false
            }

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: cell.advanceWidth * 92 + Theme.pad * 2
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
                    T { id: title; text: "[ ~/settings/input/binds/ ]"; color: Theme.accent; font.bold: true }
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
                            id: search

                            Layout.fillWidth: true
                            focus: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            renderType: Text.NativeRendering
                            enabled: !win.editing

                            Keys.onPressed: event => {
                                const k = event.key, ctrl = event.modifiers & Qt.ControlModifier;
                                if (k === Qt.Key_Escape) root.open = false;
                                else if (k === Qt.Key_Down || (ctrl && k === Qt.Key_J)) list.incrementCurrentIndex();
                                else if (k === Qt.Key_Up || (ctrl && k === Qt.Key_K)) list.decrementCurrentIndex();
                                else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (win.cur) win.startEdit(win.cur); }
                                else if (ctrl && k === Qt.Key_A) win.startEdit(null);
                                else if (ctrl && k === Qt.Key_D) { if (win.cur) Binds.disable(win.cur.combo); }
                                else if (ctrl && k === Qt.Key_R) { if (win.cur) Binds.reset(win.cur.combo); }
                                else return;
                                event.accepted = true;
                            }
                        }

                        T { text: win.results.length + "/" + Binds.all.length; color: Theme.gray }
                    }

                    // старые установки: свои бинды не подключены
                    T {
                        Layout.fillWidth: true
                        visible: !Binds.included
                        wrapMode: Text.Wrap
                        textFormat: Text.StyledText
                        text: `<font color="${Theme.yellow}">! в config.kdl нет include "nopox/keys.kdl" — свои бинды не применятся.</font> `
                            + `<font color="${Theme.accent}">[подключить]</font>`

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Binds.ensureIncluded()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        implicitHeight: win.lineH * win.rows
                        clip: true
                        model: win.results
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: line

                            required property var modelData
                            required property int index
                            readonly property var b: modelData.b
                            readonly property bool current: ListView.isCurrentItem

                            width: list.width
                            height: win.lineH
                            color: current ? Theme.bg1 : "transparent"

                            RowLayout {
                                anchors { fill: parent; rightMargin: Theme.pad }
                                spacing: 0

                                T { text: line.current ? "▌ " : "  "; color: Theme.accent }
                                T {
                                    Layout.preferredWidth: cell.advanceWidth * 24
                                    textFormat: Text.StyledText
                                    text: Fuzzy.highlight(line.b.combo, line.modelData.pos, Theme.orange)
                                    color: line.b.off ? Theme.gray : Theme.blue
                                    font.bold: line.current
                                    font.strikeout: line.b.off
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                    text: line.b.off ? "отключено" : (line.b.title || line.b.action)
                                    color: line.b.off ? Theme.gray : line.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                }
                                T {
                                    text: "  " + ({ config: "config", nopox: "nopox", own: "своё", changed: "изменено" })[line.b.source]
                                    color: line.b.source === "changed" || line.b.source === "own" ? Theme.accent : Theme.gray
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: list.currentIndex = line.index
                                onDoubleClicked: win.startEdit(line.b)
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.bg2 }

                    // ── редактор ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: win.editing
                        spacing: 2

                        T {
                            text: win.origCombo ? "изменить " + win.origCombo : "новый бинд"
                            color: Theme.accent
                            font.bold: true
                        }

                        EditField {
                            id: comboField

                            Layout.fillWidth: true
                            label: "сочетание"
                            hint: "нажмите или введите: Mod+Shift+T"
                            active: win.field === 0
                            textColor: Theme.blue
                            labelWidth: cell.advanceWidth * 12
                            lineHeight: win.lineH
                            onActivated: win.field = 0

                            // сочетание с Ctrl/Alt/Super — захватываем целиком; Shift+символ — просто ввод
                            onKeyPressed: event => {
                                if (win.editorKeys(event)) return;
                                const m = event.modifiers;
                                if (!(m & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return;
                                const name = root.keyName(event.key, event.text);
                                if (!name) return;      // нажат только модификатор
                                const mods = [];
                                if (m & Qt.MetaModifier) mods.push("Mod");
                                if (m & Qt.ControlModifier) mods.push("Ctrl");
                                if (m & Qt.AltModifier) mods.push("Alt");
                                if (m & Qt.ShiftModifier) mods.push("Shift");
                                comboField.text = mods.concat([name]).join("+");
                                event.accepted = true;
                            }
                        }

                        EditField {
                            id: actionField

                            Layout.fillWidth: true
                            label: "действие"
                            hint: "close-window · focus-workspace 3 · spawn kitty -e btop · off"
                            active: win.field === 1
                            labelWidth: cell.advanceWidth * 12
                            lineHeight: win.lineH
                            onActivated: win.field = 1

                            // ↑↓ — подставить подсказку
                            onKeyPressed: event => {
                                if (win.editorKeys(event)) return;
                                const n = win.suggestions.length;
                                if (!n) return;
                                if (event.key === Qt.Key_Down) win.sugIndex = (win.sugIndex + 1) % n;
                                else if (event.key === Qt.Key_Up) win.sugIndex = (win.sugIndex - 1 + n) % n;
                                else { win.sugIndex = -1; return; }
                                actionField.text = win.suggestions[win.sugIndex].name;
                                event.accepted = true;
                            }
                        }

                        EditField {
                            id: titleField

                            Layout.fillWidth: true
                            label: "подпись"
                            hint: "для подсказки клавиш niri (Mod+Shift+/), можно пусто"
                            active: win.field === 2
                            labelWidth: cell.advanceWidth * 12
                            lineHeight: win.lineH
                            onActivated: win.field = 2
                            onKeyPressed: event => win.editorKeys(event)
                        }

                        T {
                            visible: win.conflict !== null
                            text: "заменит: " + (win.conflict?.combo ?? "") + " → " + (win.conflict?.title || win.conflict?.action || "")
                            color: Theme.yellow
                        }

                        // подсказки действий: ↑↓ подставляют
                        Repeater {
                            model: win.suggestions

                            T {
                                required property var modelData
                                required property int index
                                textFormat: Text.StyledText
                                text: (index === win.sugIndex ? `<font color="${Theme.accent}">▌ </font>` : "  ")
                                    + `<font color="${Theme.fg}">${modelData.name.replace(/</g, "&lt;")}</font>`
                                    + `<font color="${Theme.gray}">  ${modelData.desc}</font>`

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { actionField.text = parent.modelData.name; win.sugIndex = parent.index; actionField.input.forceActiveFocus(); }
                                }
                            }
                        }
                    }


                    T {
                        Layout.fillWidth: true
                        visible: Binds.error !== ""
                        wrapMode: Text.Wrap
                        text: Binds.error
                        color: Theme.red
                    }

                    T {
                        Layout.alignment: Qt.AlignRight
                        textFormat: Text.StyledText
                        color: Theme.gray
                        text: (win.editing
                            ? [["↵", "сохранить"], ["⇥", "поле"], ["↑↓", "подсказки"], ["esc", "отмена"]]
                            : [["↵", "изменить"], ["^a", "добавить"], ["^d", "отключить"], ["^r", "вернуть"], ["esc", "выход"]])
                            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
                    }
                }
            }
        }
    }
}
