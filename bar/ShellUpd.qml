import QtQuick
import qs
import qs.bar
import qs.services

// nopox ↑3 — новые коммиты nopox-shell на GitHub. Клик: список и [обновить], правый клик: проверить сейчас.
// Без обновлений скрыт.
Seg {
    id: root

    available: ShellUpdate.behind > 0 || ShellUpdate.updating || popup.open
    label: "nopox"
    value: ShellUpdate.updating ? "…" : "↑" + ShellUpdate.behind
    valueColor: Theme.accent
    bold: true

    onLeftClicked: popup.toggle()
    onRightClicked: ShellUpdate.check(true)

    ShellUpdPopup { id: popup; owner: root; bar: root.bar }
}
