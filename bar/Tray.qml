import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.bar
import qs.services

// [‹ telegram discord] — трей текстом: клик — открыть, правый клик — меню.
// ‹ сворачивает трей в [+2]; приложения, которые просят внимания, видны и в свёрнутом.
Item {
    id: root

    property var bar
    readonly property var items: SystemTray.items.values
    readonly property bool collapsed: Settings.get("shell.bar.trayCollapsed")
    readonly property var shown: collapsed ? items.filter(it => it.status === Status.NeedsAttention) : items
    readonly property int hidden: items.length - shown.length
    property bool available: items.length > 0

    function shortName(it) {
        return (it.title || it.id || "?").toLowerCase().split(/[\s._-]+/)[0].slice(0, 12);
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
            model: root.shown

            T {
                id: item

                required property var modelData

                text: " " + root.shortName(modelData)
                color: modelData.status === Status.NeedsAttention ? Theme.accent : Theme.fg

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

        T { text: "]"; color: Theme.gray }
    }

    // своё меню вместо it.display(): нативному QMenu нужен режим QApplication, и он не в стиле shell
    TrayMenu { id: menu; bar: root.bar; owner: root }
}
