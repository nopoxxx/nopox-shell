import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.bar

// [telegram discord] — трей текстом: клик — открыть, правый клик — меню
Item {
    id: root

    property var bar
    readonly property var items: SystemTray.items.values
    property bool available: items.length > 0

    function shortName(it) {
        return (it.title || it.id || "?").toLowerCase().split(/[\s._-]+/)[0].slice(0, 12);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row

        T { text: "["; color: Theme.gray }

        Repeater {
            model: root.items

            T {
                id: item

                required property var modelData
                required property int index

                text: (index > 0 ? " " : "") + root.shortName(modelData)
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
