import QtQuick
import qs

// Стиль анимации «type» (Reveal.qml): source печатается по символу в сетке шрифта, слева направо и сверху вниз.
// Перед курсором █ бежит полоса случайных знаков, за ним проступает настоящее содержимое; закрытие стирает с конца.
// TypeOn — сосед source (тот же родитель, выше по z), не потомок: пока active, source спрятан (hideSource),
// а напечатанная часть рисуется его копиями (ShaderEffectSource) в двух окошках — целые строки и начало текущей.
//   TypeOn { anchors.fill: parent; source: box; p: reveal.p; active: reveal.printing }
Item {
    id: tp

    property Item source
    property real p: 1
    property bool active: false
    property real margin: 0           // сколько захватить над source: заголовок на линии рамки

    visible: active

    TextMetrics {
        id: cell
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: "M"
    }

    readonly property real cw: cell.advanceWidth
    readonly property real ch: Math.ceil(cell.height)
    readonly property rect area: source ? Qt.rect(source.x, source.y - margin, source.width, source.height + margin) : Qt.rect(0, 0, 0, 0)
    readonly property int cols: Math.max(1, Math.ceil(area.width / cw))
    readonly property int rows: Math.max(1, Math.ceil(area.height / ch))
    readonly property int done: Math.floor(Math.min(1, Math.max(0, p)) * cols * rows)
    readonly property int fullRows: Math.floor(done / cols)
    readonly property int col: done % cols
    // полоса «шума» перед курсором — полстроки, не больше 24 знаков
    readonly property int band: Math.min(24, Math.ceil(cols / 2), cols * rows - done)

    // напечатанное: целые строки…
    Item {
        x: tp.area.x
        y: tp.area.y
        width: tp.area.width
        height: Math.min(tp.area.height, tp.fullRows * tp.ch)
        clip: true
        ShaderEffectSource {
            sourceItem: tp.active ? tp.source : null
            hideSource: tp.active
            sourceRect: Qt.rect(0, -tp.margin, tp.area.width, tp.area.height)
            width: tp.area.width
            height: tp.area.height
        }
    }

    // …и начало текущей
    Item {
        x: tp.area.x
        y: tp.area.y + tp.fullRows * tp.ch
        width: tp.col * tp.cw
        height: tp.ch
        clip: true
        ShaderEffectSource {
            y: -tp.fullRows * tp.ch
            sourceItem: tp.active ? tp.source : null
            hideSource: tp.active
            sourceRect: Qt.rect(0, -tp.margin, tp.area.width, tp.area.height)
            width: tp.area.width
            height: tp.area.height
        }
    }

    // шум: обновляется, пока идёт печать
    readonly property string glyphs: "#$%&*+-/<=>?@[]^_{|}~01░▒▓╱╲┼═║"
    property string noise: ""

    function shuffle() {
        let s = "";
        for (let i = 0; i < band; i++) s += glyphs[Math.floor(Math.random() * glyphs.length)];
        noise = s;
    }

    Timer {
        interval: 40
        repeat: true
        running: tp.active
        triggeredOnStart: true
        onTriggered: tp.shuffle()
    }

    // полоса может перейти на следующую строку: кусок до конца текущей и остаток с начала следующей
    Repeater {
        model: [
            { row: tp.fullRows, from: tp.col, n: Math.min(tp.band, tp.cols - tp.col), at: 0 },
            { row: tp.fullRows + 1, from: 0, n: Math.max(0, tp.band - (tp.cols - tp.col)), at: tp.cols - tp.col }
        ]

        Rectangle {
            required property var modelData

            visible: modelData.n > 0 && modelData.row < tp.rows
            x: tp.area.x + modelData.from * tp.cw
            y: tp.area.y + modelData.row * tp.ch
            width: modelData.n * tp.cw
            height: tp.ch
            color: Theme.bg

            T {
                textFormat: Text.StyledText
                text: {
                    const m = parent.modelData;
                    const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                    const s = tp.noise.substr(m.at, m.n);
                    // первый знак полосы — курсор
                    return m.at === 0
                        ? `<font color="${Theme.accent}">█</font><font color="${Theme.gray}">${esc(s.slice(1))}</font>`
                        : `<font color="${Theme.gray}">${esc(s)}</font>`;
                }
            }
        }
    }
}
