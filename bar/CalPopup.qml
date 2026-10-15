import QtQuick
import QtQuick.Layouts
import qs
import qs.bar

// Календарь как вывод `cal`: ‹ › или колёсико — соседние месяцы, сегодня выделено акцентом
TuiPopup {
    id: pop

    title: "cal"

    property int offset: 0
    property var now: new Date()
    readonly property var loc: Qt.locale()
    readonly property var month: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int firstDay: loc.firstDayOfWeek % 7   // 0 — воскресенье, как в Date.getDay()
    readonly property var cells: {
        const y = month.getFullYear(), m = month.getMonth();
        const lead = (month.getDay() - firstDay + 7) % 7;
        const days = new Date(y, m + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++) out.push(0);
        for (let d = 1; d <= days; d++) out.push(d);
        return out;
    }

    onOpenChanged: if (open) { now = new Date(); offset = 0; }

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "000"
    }

    RowLayout {
        Layout.fillWidth: true

        T {
            text: "‹"
            color: Theme.accent
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.offset-- }
        }
        T {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: pop.loc.standaloneMonthName(pop.month.getMonth()) + " " + pop.month.getFullYear()
            color: Theme.fg
            font.bold: true
        }
        T {
            text: "›"
            color: Theme.accent
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.offset++ }
        }
    }

    Grid {
        columns: 7

        Repeater {
            model: 7
            T {
                required property int index
                readonly property int day: (pop.firstDay + index) % 7
                width: cell.advanceWidth
                horizontalAlignment: Text.AlignHCenter
                text: pop.loc.dayName(day, Locale.ShortFormat).slice(0, 2)
                color: day === 0 || day === 6 ? Theme.red : Theme.gray
            }
        }

        Repeater {
            model: pop.cells

            Rectangle {
                required property int modelData
                required property int index
                readonly property bool today: modelData > 0 && pop.offset === 0 && modelData === pop.now.getDate()
                readonly property int weekday: (pop.firstDay + index) % 7

                width: cell.advanceWidth
                height: dayText.implicitHeight
                color: today ? Theme.accent : "transparent"

                T {
                    id: dayText
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    color: parent.today ? Theme.bg : parent.weekday === 0 || parent.weekday === 6 ? Theme.red : Theme.fg
                    font.bold: parent.today
                }
            }
        }
        // колёсико по календарю листает месяцы
        WheelHandler {
            onWheel: event => pop.offset += event.angleDelta.y > 0 ? -1 : 1
        }
    }
}
