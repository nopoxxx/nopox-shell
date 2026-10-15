import QtQuick
import qs
import qs.bar
import qs.services

// upd 12 — клик: paru -Syu в kitty, правый клик: проверить сейчас. Без обновлений скрыт.
Seg {
    available: Updates.count > 0 || Updates.running
    label: "upd"
    value: Updates.running ? "…" : String(Updates.count)
    valueColor: Theme.aqua
    onLeftClicked: Updates.run()
    onRightClicked: Updates.check()
}
