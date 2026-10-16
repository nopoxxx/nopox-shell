import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs.services

// Уведомление как запись лога в TUI-рамке: ┌─[ 21:06 INFO firefox ]───
// Клик — действие по умолчанию, правый клик — закрыть, наведение ставит таймер на паузу.
// Линия внизу показывает, сколько осталось до исчезновения.
Item {
    id: card

    required property int key
    readonly property var entry: Notifs.entries[key] ?? null
    readonly property bool critical: entry?.urgency === NotificationUrgency.Critical
    readonly property color levelColor: critical ? Theme.red
        : entry?.urgency === NotificationUrgency.Low ? Theme.gray
        : Theme.accent
    readonly property int timeout: (entry?.notif?.expireTimeout ?? 0) > 0
        ? entry.notif.expireTimeout
        : Settings.get("shell.notify.timeout") * 1000
    readonly property bool sticky: critical && Settings.get("shell.notify.criticalSticky")
    readonly property var buttons: (entry?.actions ?? []).filter(a => a.id !== "default" && a.text)

    property real remaining: 1

    // заголовок уведомления печатается по символу, как команда на панели
    readonly property string summary: entry?.summary ?? ""
    property int typed: Settings.get("shell.notify.typing") ? 0 : summary.length

    function c(color, s) { return `<font color="${color}">${s}</font>`; }

    // появление и уход (Reveal.qml): закрытая карточка сначала доигрывает анимацию, потом afterLeave()
    property bool leaving: false
    property var afterLeave: null

    function leave(fn) {
        if (leaving || !entry) return;
        afterLeave = fn;
        leaving = true;
    }

    Reveal {
        id: reveal
        open: !card.leaving
        style: Settings.get("shell.notify.anim")
        duration: 200
        edge: Settings.get("shell.notify.position").endsWith("right") ? "right" : "left"
        distance: card.width * 0.4
        onHidden: if (card.afterLeave) card.afterLeave()
    }

    opacity: reveal.alpha
    scale: reveal.zoom
    transform: [
        Translate { x: reveal.dx },
        Scale { yScale: reveal.ys }
    ]

    width: cell.advanceWidth * 46 + Theme.pad * 2
    implicitHeight: frame.y + frame.height

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "M"
    }

    Timer {
        interval: 14
        repeat: true
        running: card.typed < card.summary.length
        onTriggered: card.typed++
    }

    NumberAnimation on remaining {
        id: life
        from: 1
        to: 0
        duration: card.timeout
        running: !card.sticky
        paused: running && hover.hovered
        onFinished: { const e = card.entry; card.leave(() => Notifs.hidePopup(e)); }
    }

    HoverHandler { id: hover }

    Rectangle {
        id: frame

        y: titleBox.height / 2
        width: parent.width
        height: col.implicitHeight + Theme.pad * 2 + titleBox.height / 2
        color: Theme.bg
        border.color: card.levelColor
        border.width: 2

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const e = card.entry;
                if (mouse.button === Qt.RightButton) card.leave(() => Notifs.dismiss(e));
                else card.leave(() => Notifs.invoke(e));
            }
        }

        ColumnLayout {
            id: col

            x: Theme.pad
            y: Theme.pad + titleBox.height / 2
            width: frame.width - Theme.pad * 2
            spacing: 2

            T {
                Layout.fillWidth: true
                visible: card.summary !== ""
                text: card.summary.slice(0, card.typed) + (card.typed < card.summary.length ? "█" : "")
                color: Theme.fg
                font.bold: true
                wrapMode: Text.Wrap
            }

            T {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.entry?.body ?? ""
                color: Theme.gray
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            // кнопки действий: [открыть] [ответить] … [×]
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: cell.advanceWidth

                Repeater {
                    model: card.buttons

                    T {
                        required property var modelData
                        text: "[" + modelData.text + "]"
                        color: Theme.accent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { const e = card.entry, a = parent.modelData; card.leave(() => Notifs.invoke(e, a)); }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                T {
                    text: "[×]"
                    color: Theme.gray

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { const e = card.entry; card.leave(() => Notifs.dismiss(e)); }
                    }
                }
            }

            // сколько осталось до исчезновения
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 2
                visible: !card.sticky
                color: Theme.bg1

                Rectangle {
                    width: parent.width * card.remaining
                    height: parent.height
                    color: card.levelColor
                }
            }
        }
    }

    // заголовок на линии рамки: ┌─[ 21:06 INFO firefox ]───
    Rectangle {
        id: titleBox

        x: Theme.pad
        width: title.implicitWidth
        height: title.implicitHeight
        color: Theme.bg

        T {
            id: title
            textFormat: Text.StyledText
            text: !card.entry ? "" : card.c(card.levelColor, "[ ")
                + card.c(Theme.gray, Qt.formatTime(card.entry.time, "HH:mm")) + " "
                + card.c(card.levelColor, "<b>" + Notifs.level(card.entry.urgency) + "</b>") + " "
                + card.c(Theme.fg, card.entry.app)
                + card.c(card.levelColor, " ]")
        }
    }
}
