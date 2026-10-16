import QtQuick
import qs

// Сегмент «label value» с кликами и колёсиком — основа большинства модулей
Item {
    id: seg

    property var bar
    property bool available: true
    property string label: ""
    property string value: ""
    property color valueColor: Theme.fg
    property bool bold: false
    // своё колёсико (vol, kbd); у остальных прокрутка уходит панели — листать рабочие столы
    property bool scrollable: false

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int dir)   // +1 — вверх, -1 — вниз

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        T { visible: seg.label !== ""; text: seg.label + " "; color: Theme.gray }
        T { text: seg.value; color: seg.valueColor; font.bold: seg.bold }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) seg.rightClicked();
            else if (mouse.button === Qt.MiddleButton) seg.middleClicked();
            else seg.leftClicked();
        }
        onWheel: wheel => {
            if (!seg.scrollable) { wheel.accepted = false; return; }
            seg.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
