import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.services
import "services/fuzzy.js" as Fuzzy

// Лаунчер в стиле fzf. Открывается через `qs ipc call launcher toggle`.
Scope {
    id: root

    property bool open: false
    readonly property int rows: 12

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open = !root.open; }
        // не `show`: это имя занято подкомандой `qs ipc show`
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }

    function launch(entry) {
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", ...entry.command]);
        else
            entry.execute();
        root.open = false;
    }

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

            readonly property var apps: DesktopEntries.applications.values
                .filter(e => !e.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))

            // по имени — с подсветкой; по описанию и ключевым словам — слабее и без неё
            readonly property var results: {
                const q = input.text.trim();
                if (!q) return apps.map(e => ({ entry: e, pos: [] }));
                const out = [];
                for (const e of apps) {
                    const byName = Fuzzy.match(q, e.name);
                    const extra = [e.genericName, e.comment, ...e.keywords].join(" ");
                    const byExtra = Fuzzy.match(q, extra);
                    const nameScore = byName ? byName.score + 5 : -Infinity;
                    const extraScore = byExtra ? byExtra.score * 0.8 : -Infinity;
                    if (byName && nameScore >= extraScore)
                        out.push({ entry: e, pos: byName.pos, score: nameScore });
                    else if (byExtra)
                        out.push({ entry: e, pos: [], score: extraScore });
                }
                return out.sort((a, b) => b.score - a.score);
            }

            onResultsChanged: list.currentIndex = 0

            property point lastMouse
            property bool lastMouseSet: false

            TextMetrics {
                id: cell
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: "M"
            }

            // клик мимо окна закрывает лаунчер
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
                border.color: Theme.yellow
                border.width: 2

                MouseArea { anchors.fill: parent }

                // заголовок на линии рамки: ┌─[ run ]────
                Rectangle {
                    x: Theme.pad
                    y: -height / 2
                    width: title.implicitWidth
                    height: title.implicitHeight
                    color: Theme.bg
                    T { id: title; text: "[ run ]"; color: Theme.yellow; font.bold: true }
                }

                ColumnLayout {
                    id: col

                    anchors { fill: parent; margins: Theme.pad }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        T { text: "❯ "; color: Theme.yellow; font.bold: true }

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
                                if (event.key === Qt.Key_Escape) {
                                    root.open = false;
                                } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                    list.incrementCurrentIndex();
                                } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                    list.decrementCurrentIndex();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    const r = win.results[list.currentIndex];
                                    if (r) root.launch(r.entry);
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }
                        }

                        T { text: win.results.length + "/" + win.apps.length; color: Theme.gray }
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
                            readonly property bool current: ListView.isCurrentItem

                            width: list.width
                            height: cell.height * 1.25
                            color: current ? Theme.bg1 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                T {
                                    text: row.current ? "▌ " : "  "
                                    color: Theme.yellow
                                }
                                T {
                                    textFormat: Text.StyledText
                                    text: Fuzzy.highlight(row.modelData.entry.name, row.modelData.pos, Theme.orange)
                                    color: row.current ? Theme.fg : Qt.darker(Theme.fg, 1.15)
                                    font.bold: row.current
                                }
                                T {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: row.modelData.entry.genericName ? "  " + row.modelData.entry.genericName : ""
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
                                onClicked: root.launch(row.modelData.entry)
                            }
                        }
                    }
                }
            }
        }
    }
}
