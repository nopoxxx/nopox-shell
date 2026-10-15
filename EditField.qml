import QtQuick
import QtQuick.Layouts

// Поле ввода в TUI-рамке: подпись слева, серая подсказка, пока пусто.
// Клавиши отдаёт наружу сигналом keyPressed — обработчик может принять событие (event.accepted = true).
RowLayout {
    id: f

    property string label
    property string hint
    property bool active: false
    property color textColor: Theme.fg
    property real labelWidth: 100
    property real lineHeight: 24
    readonly property alias input: inp
    property alias text: inp.text

    signal keyPressed(var event)
    signal activated()

    spacing: 0

    T {
        Layout.preferredWidth: f.labelWidth
        text: (f.active ? "▌ " : "  ") + f.label
        color: f.active ? Theme.accent : Theme.gray
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: f.lineHeight
        color: Theme.bg1
        border.color: f.active ? Theme.accent : Theme.bg2
        border.width: 1

        TextInput {
            id: inp

            anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            clip: true
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: f.textColor
            selectionColor: Theme.bg2
            renderType: Text.NativeRendering

            Keys.onPressed: event => f.keyPressed(event)
            onActiveFocusChanged: if (activeFocus) f.activated()
        }

        T {
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            visible: inp.text === ""
            text: f.hint
            color: Theme.bg2
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: inp.forceActiveFocus()
        }
    }
}
