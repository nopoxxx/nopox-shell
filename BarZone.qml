import QtQuick
import qs.services
// модули грузятся через Loader по URL — импорт нужен, чтобы quickshell просканировал bar/
import qs.bar
import "services/settings.js" as S

// Зона панели: модули по списку id с разделителями между видимыми.
// Модуль сам сообщает, есть ли ему что показать (property available) — скрытые не дают лишних разделителей.
Row {
    id: zone

    required property var ids
    required property var bar

    function prevShown(i) {
        for (let j = i - 1; j >= 0; j--) {
            const it = rep.itemAt(j);
            if (it && it.shown) return it;
        }
        return null;
    }

    Repeater {
        id: rep

        model: zone.ids

        Row {
            id: slot

            required property string modelData
            required property int index
            readonly property var mod: S.moduleById(modelData)
            readonly property bool shown: loader.item !== null && loader.item.available !== false

            visible: shown

            T {
                text: {
                    rep.count; // пересчитать, когда создадутся соседние слоты
                    const p = zone.prevShown(slot.index);
                    if (!p) return "";
                    return p.mod.inline && slot.mod.inline ? " " : zone.bar.separator;
                }
                visible: text !== ""
                color: Theme.bg2
            }

            Loader {
                id: loader
                Component.onCompleted: setSource(Qt.resolvedUrl("bar/" + slot.mod.file + ".qml"), { bar: zone.bar })
            }
        }
    }
}
