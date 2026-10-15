import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.bar
import qs.services

// [‹ telegram discord] — трей текстом: клик — открыть, правый клик — меню.
// ‹ сворачивает трей в [+2]; приложения, которые просят внимания, видны и в свёрнутом.
// Названия печатаются при разворачивании и стираются при сворачивании — как команда в Command.qml.
Item {
    id: root

    property var bar
    readonly property var items: SystemTray.items.values
    readonly property bool collapsed: Settings.get("shell.bar.trayCollapsed")
    property bool available: items.length > 0

    // сворачиваются только обычные значки; просящие внимания видны всегда
    readonly property var plain: items.filter(it => it.status !== Status.NeedsAttention)
    readonly property int hidden: collapsed ? plain.length : 0

    function shortName(it) {
        return (it.title || it.id || "?").toLowerCase().split(/[\s._-]+/)[0].slice(0, 12);
    }

    // ── анимация набора: typed — сколько символов обычных значков сейчас видно ──
    readonly property int totalLen: plain.reduce((n, it) => n + 1 + shortName(it).length, 0)
    readonly property int target: collapsed ? 0 : totalLen
    property int typed: 0
    readonly property bool typing: typed !== target

    function offsetOf(it) {
        let n = 0;
        for (const p of plain) {
            if (p === it) return n;
            n += 1 + shortName(p).length;
        }
        return 0;
    }

    onTargetChanged: {
        if (Settings.get("shell.bar.trayTyping")) typer.start();
        else typed = target;
    }

    Component.onCompleted: typed = target

    Timer {
        id: typer
        interval: 14
        repeat: true
        onTriggered: {
            root.typed += root.typed < root.target ? 1 : -1;
            if (!root.typing) stop();
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        // переключатель «[‹» / «[+N»: ‹ — свернуть, +N — развернуть.
        // Кликабельна и скобка, и немного вокруг — один символ слишком мелкая цель.
        T {
            textFormat: Text.StyledText
            text: `<font color="${Theme.gray}">[</font>`
                + `<font color="${root.collapsed ? Theme.accent : Theme.gray}">${root.collapsed ? "+" + root.hidden : "‹"}</font>`

            MouseArea {
                anchors { fill: parent; margins: -6 }
                cursorShape: Qt.PointingHandCursor
                onClicked: Settings.set("shell.bar.trayCollapsed", !root.collapsed)
            }
        }

        Repeater {
            model: root.items

            T {
                id: item

                required property var modelData
                readonly property bool attention: modelData.status === Status.NeedsAttention
                readonly property string full: " " + root.shortName(modelData)
                readonly property int start: attention ? 0 : root.offsetOf(modelData)

                visible: text.length > 0
                text: attention ? full : full.slice(0, Math.max(0, Math.min(full.length, root.typed - start)))
                color: attention ? Theme.accent : Theme.fg

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const it = item.modelData;
                        if (mouse.button === Qt.RightButton || it.onlyMenu) {
                            if (it.hasMenu) menu.openFor(item, it, root.shortName(it));
                        } else {
                            it.activate();
                        }
                    }
                }
            }
        }

        // курсор, пока названия печатаются или стираются
        T { visible: root.typing; text: "█"; color: Theme.fg }

        T { text: "]"; color: Theme.gray }
    }

    // своё меню вместо it.display(): нативному QMenu нужен режим QApplication, и он не в стиле shell
    TrayMenu { id: menu; bar: root.bar; owner: root }
}
