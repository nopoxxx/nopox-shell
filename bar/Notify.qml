import QtQuick
import qs
import qs.bar
import qs.services

// log 3 — непрочитанные уведомления; dnd — режим «не беспокоить».
// Клик: история, правый клик: «не беспокоить».
Seg {
    id: root

    label: "log"
    value: Notifs.dnd ? "dnd" : String(Notifs.unread)
    valueColor: Notifs.dnd ? Theme.purple : Notifs.unread > 0 ? Theme.accent : Theme.gray
    bold: Notifs.unread > 0

    onLeftClicked: {
        center.toggle();
        Notifs.markRead();
    }
    onRightClicked: Notifs.toggleDnd()

    NotifyCenter { id: center; owner: root; bar: root.bar }
}
