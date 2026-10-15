import QtQuick
import QtQuick.Layouts
import qs

// name  [██████░░░░░░] 60% — клик по полосе ставит громкость, колёсико ±5%, клик по имени — mute
RowLayout {
    id: row

    property var node
    property string label
    readonly property real vol: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property int cells: 24
    readonly property int filled: Math.round(Math.min(1, vol) * cells)

    function setVol(v) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, v));
    }

    spacing: 0

    T {
        text: row.label.slice(0, 16).padEnd(17)
        color: row.muted ? Theme.gray : Theme.fg

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.node?.audio) row.node.audio.muted = !row.muted
        }
    }

    T {
        id: gauge

        text: "[" + "█".repeat(row.filled) + "░".repeat(row.cells - row.filled) + "]"
        color: row.muted ? Theme.gray : Theme.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            // скобки занимают по символу с краёв
            onClicked: mouse => {
                const ch = gauge.width / (row.cells + 2);
                row.setVol((mouse.x - ch) / (gauge.width - 2 * ch));
            }
            onWheel: wheel => row.setVol(row.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    T {
        text: row.muted ? " muted" : (" " + Math.round(row.vol * 100) + "%").padStart(5)
        color: Theme.gray
    }
}
