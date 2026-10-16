import QtQuick
import qs
import qs.bar
import qs.services

// Значок меню home — для тех, у кого user@host убран с панели; клик — открыть (как Mod+A).
Seg {
    id: root

    value: "≡"
    valueColor: Home.open ? Theme.accent : Theme.fg
    bold: true

    onLeftClicked: Home.toggle(root.bar?.screen?.name)
}
