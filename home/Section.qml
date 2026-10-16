import QtQuick
import QtQuick.Layouts
import qs

// База секции меню home: заголовок «── погода ─────» и фокус с клавиатуры.
// Секция говорит, сколько у неё элементов под фокус (count), и рисует выделение у isCur(i).
// ↑↓ между элементами и секциями двигает панель; остальные клавиши сначала получает key(event),
// не обработала — ↵/Space вызывают activate(cur). Нечего показать (нет устройства) — available: false.
ColumnLayout {
    id: sec

    property var panel                // HomePanel: cell, close()
    property string title
    property bool available: true
    property int count: 0
    property int cur: 0
    property bool focused: false
    default property alias content: body.data

    function isCur(i) { return focused && cur === i; }
    function key(event) { return false; }
    function activate(i) {}

    // клик мышью ставит фокус туда же, куда пришли бы клавишами
    function pick(i) {
        cur = i;
        panel.focusSection(sec);
    }

    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0
        T { text: "── " + sec.title + " "; color: sec.focused ? Theme.accent : Theme.gray }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: sec.focused ? Theme.accent : Theme.bg2 }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 2
    }
}
