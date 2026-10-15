import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services

// Экран входа как getty в консоли:
//
//          ██████  ██████    ██████  ██  ██
//          ...                                    (tty-clock)
//               четверг, 16 октября 2026
//
//     nopox-os 7.2.9-arch1-1 (tty1)
//     nopox-os login: nopox
//     Password: ****█
//     Login incorrect
//
// Общий для блокировки экрана (PAM) и greeter (greetd): сам ничего не проверяет,
// только отдаёт пароль сигналом submit.
Item {
    id: root

    property string user: Sys.user
    property string host: Sys.host
    property string message: ""
    property bool messageIsError: false
    property bool busy: false
    property int failures: 0
    property int attempt: 0          // меняется после каждой проверки — поле очищается

    signal submit(string password)
    signal cancel()     // Esc на пустом поле — для предпросмотра и greeter

    readonly property string echo: Settings.get("shell.lock.echo")
    readonly property string masked: echo === "none" ? "" : echo.repeat(input.text.length)

    onAttemptChanged: input.text = ""

    function c(color, s) { return `<font color="${color}">${s}</font>`; }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "M"
    }

    // настоящий ввод невидим — на экране своё «эхо» пароля
    TextInput {
        id: input

        opacity: 0
        width: 1
        focus: true
        enabled: !root.busy

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (input.text.length) root.submit(input.text);
            } else if (event.key === Qt.Key_Escape) {
                if (input.text.length) input.text = "";
                else root.cancel();
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    // клик в любом месте возвращает фокус полю пароля
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.pad

        BigClock {
            Layout.alignment: Qt.AlignHCenter
            visible: Settings.get("shell.lock.clock")
            text: Qt.formatTime(clock.date, "HH:mm")
            px: Theme.fontSize * 0.9
        }

        T {
            Layout.alignment: Qt.AlignHCenter
            visible: Settings.get("shell.lock.clock")
            // Qt.locale(), а не Qt.formatDate: тот игнорирует системную локаль и пишет по-английски
            text: Qt.locale().toString(clock.date, "dddd, d MMMM yyyy")
            color: Theme.gray
        }

        Item { implicitHeight: Theme.pad * 3 }

        // приглашение — блок с выравниванием по левому краю, как в консоли
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: cell.advanceWidth * 44
            spacing: 2

            T {
                text: root.host + " " + Sys.kernel + " (tty1)"
                color: Theme.gray
            }

            Item { implicitHeight: Theme.pad }

            T {
                textFormat: Text.StyledText
                text: root.c(Theme.aqua, root.host) + root.c(Theme.fg, " login: ") + root.c(Theme.green, "<b>" + root.user + "</b>")
            }

            Row {
                T { text: "Password: "; color: Theme.fg }
                T { text: root.masked; color: Theme.accent }

                T {
                    id: cursor
                    text: "█"
                    color: Theme.fg
                    visible: !root.busy

                    Timer {
                        interval: 530
                        running: cursor.visible
                        repeat: true
                        onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1
                    }
                }
            }

            Item { implicitHeight: Theme.pad }

            T {
                visible: root.busy || root.message !== ""
                text: root.busy ? "проверка…" : root.message
                color: root.busy ? Theme.gray : root.messageIsError ? Theme.red : Theme.yellow
            }

            T {
                visible: root.failures > 1 && !root.busy
                text: root.failures + " неудачные попытки"
                color: Theme.gray
            }
        }
    }

    T {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Theme.pad * 3 }
        textFormat: Text.StyledText
        color: Theme.gray
        text: [["↵", "войти"], ["esc", "очистить"]]
            .map(([k, v]) => `<font color="${Theme.accent}">${k}</font> ${v}`).join("   ")
    }
}
