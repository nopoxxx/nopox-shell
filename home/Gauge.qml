import QtQuick
import QtQuick.Layouts
import qs

// Ползунок «󰕾 vol   ▕██████████░░░░▏  62%»: клик и перетаскивание по полосе, колёсико ±5%,
// с клавиатуры ←→ (секция вызывает step). Клик по подписи — toggled (mute).
RowLayout {
    id: g

    property string icon: ""
    property string label: ""
    property real value: 0            // 0…1
    property bool off: false          // mute — серым
    property bool current: false
    property int cells: 20
    signal moved(real v)
    signal toggled()

    readonly property int filled: Math.round(Math.max(0, Math.min(1, value)) * cells)

    function step(d) { moved(Math.max(0, Math.min(1, value + d * 0.05))); }

    spacing: 0

    T { text: g.current ? "▌" : " "; color: Theme.accent }
    Item {
        implicitWidth: lbl.implicitWidth
        implicitHeight: lbl.implicitHeight
        Row {
            id: lbl
            T { font.family: Theme.iconFont; text: g.icon + " "; color: g.off ? Theme.gray : Theme.accent }
            T { text: g.label.padEnd(8); color: g.off ? Theme.gray : g.current ? Theme.fg : Qt.darker(Theme.fg, 1.15); font.bold: g.current }
        }
        TapHandler { onTapped: g.toggled() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    T {
        id: bar
        text: "▕" + "█".repeat(g.filled) + "░".repeat(g.cells - g.filled) + "▏"
        color: g.off ? Theme.gray : Theme.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function at(x) {
                const ch = bar.width / (g.cells + 2);
                g.moved(Math.max(0, Math.min(1, (x - ch) / (bar.width - 2 * ch))));
            }
            onPressed: mouse => at(mouse.x)
            onPositionChanged: mouse => { if (pressed) at(mouse.x); }
            onWheel: wheel => g.step(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
    T {
        Layout.fillWidth: true
        text: g.off ? " muted" : (" " + Math.round(g.value * 100) + "%").padStart(5)
        color: Theme.gray
    }
}
