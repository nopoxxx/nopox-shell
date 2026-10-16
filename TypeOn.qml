import QtQuick
import qs

// Стиль анимации «type» (Reveal.qml): source печатается по символу в сетке шрифта.
//   direction: "rows"    — как текст: слева направо и сверху вниз (меню, уведомления);
//              "columns" — все строки сразу слева направо, шлейф на всю высоту (высокая колонка home).
// Перед курсором █ бежит шлейф случайных знаков, за ним проступает настоящее содержимое; закрытие стирает с конца.
// TypeOn — сосед source (тот же родитель, выше по z), не потомок: пока active, source спрятан (hideSource),
// а напечатанная часть рисуется его копиями (ShaderEffectSource) в двух окошках — целые строки и начало текущей.
//   TypeOn { anchors.fill: parent; source: box; p: reveal.p; active: reveal.printing }
Item {
    id: tp

    property Item source
    property real p: 1
    property bool active: false
    property real margin: 0           // сколько захватить над source: заголовок на линии рамки
    property string direction: "rows"
    property int trail: -1            // длина шлейфа в знаках; -1 — по умолчанию

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
    readonly property real pc: Math.min(1, Math.max(0, p))
    readonly property bool byColumns: direction === "columns"

    // rows: напечатано done знаков — fullRows целых строк и col знаков текущей; шлейф — полстроки, не больше 24
    readonly property int done: Math.floor(pc * cols * rows)
    readonly property int fullRows: Math.floor(done / cols)
    readonly property int col: done % cols
    readonly property int maxBand: trail >= 0 ? trail : Math.min(24, Math.ceil(cols / 2))
    readonly property int band: Math.min(maxBand, cols * rows - done)

    // columns: голова шлейфа проходит cols + длина шлейфа, чтобы шлейф и вырос в начале, и ушёл за край в конце
    readonly property int colTrail: trail >= 0 ? trail : Math.ceil(cols * 0.4)
    readonly property int head: Math.floor(pc * (cols + colTrail))
    readonly property int printedCols: Math.max(0, Math.min(cols, head - colTrail))
    readonly property int bandCols: Math.max(0, Math.min(cols, head) - printedCols)

    // напечатанное: целые строки (columns — готовые столбцы)…
    Item {
        x: tp.area.x
        y: tp.area.y
        width: tp.byColumns ? tp.printedCols * tp.cw : tp.area.width
        height: tp.byColumns ? tp.area.height : Math.min(tp.area.height, tp.fullRows * tp.ch)
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
        visible: !tp.byColumns
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
        // с запасом на самый широкий шлейф: он меняется каждый кадр, а шум — раз в 40 мс
        const n = byColumns ? colTrail * rows : maxBand;
        for (let i = 0; i < n; i++) s += glyphs[Math.floor(Math.random() * glyphs.length)];
        noise = s;
    }

    Timer {
        interval: 40
        repeat: true
        running: tp.active
        triggeredOnStart: true
        onTriggered: tp.shuffle()
    }

    // columns: шлейф на всю высоту, курсор █ — первым столбцом
    Rectangle {
        visible: tp.byColumns && tp.bandCols > 0
        x: tp.area.x + tp.printedCols * tp.cw
        y: tp.area.y
        width: tp.bandCols * tp.cw
        height: tp.rows * tp.ch
        color: Theme.bg

        Column {
            Repeater {
                model: tp.byColumns ? tp.rows : 0

                T {
                    required property int index
                    height: tp.ch
                    textFormat: Text.StyledText
                    text: {
                        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                        const s = tp.noise.substr(index * tp.colTrail, tp.bandCols);
                        return `<font color="${Theme.accent}">█</font><font color="${Theme.gray}">${esc(s.slice(1))}</font>`;
                    }
                }
            }
        }
    }

    // rows: полоса может перейти на следующую строку — кусок до конца текущей и остаток с начала следующей
    Repeater {
        model: tp.byColumns ? [] : [
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
