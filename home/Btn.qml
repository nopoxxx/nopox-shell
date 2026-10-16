import QtQuick
import qs

// Кнопка «[󰖩 wifi]» меню home: on — включено (акцент), current — в фокусе с клавиатуры.
Rectangle {
    id: btn

    property string icon: ""
    property string text: ""
    property bool on: false
    property bool current: false
    property bool active: true       // false — нечего переключать (нет устройства)
    property color onColor: Theme.accent
    signal clicked()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    color: current ? Theme.bg1 : hover.hovered && active ? Qt.darker(Theme.bg1, 1.3) : "transparent"

    readonly property color fg: !active ? Theme.bg2 : on ? onColor : current ? Theme.fg : Qt.darker(Theme.fg, 1.15)

    Row {
        id: row
        T { text: "["; color: btn.current ? Theme.accent : Theme.gray }
        T { visible: btn.icon !== ""; font.family: Theme.iconFont; text: btn.icon + (btn.text ? " " : ""); color: btn.fg }
        T { text: btn.text; color: btn.fg; font.bold: btn.current }
        T { text: "]"; color: btn.current ? Theme.accent : Theme.gray }
    }

    HoverHandler { id: hover; cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: btn.active; onTapped: btn.clicked() }
}
