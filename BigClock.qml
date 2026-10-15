import QtQuick

// Крупные часы из блоков, как tty-clock: каждая цифра — сетка 3×5 «пикселей»
Row {
    id: root

    property string text: "00:00"
    property real px: 14
    property color color: Theme.accent

    readonly property var glyphs: ({
        "0": ["###", "# #", "# #", "# #", "###"],
        "1": ["## ", " # ", " # ", " # ", "###"],
        "2": ["###", "  #", "###", "#  ", "###"],
        "3": ["###", "  #", "###", "  #", "###"],
        "4": ["# #", "# #", "###", "  #", "  #"],
        "5": ["###", "#  ", "###", "  #", "###"],
        "6": ["###", "#  ", "###", "# #", "###"],
        "7": ["###", "  #", "  #", "  #", "  #"],
        "8": ["###", "# #", "###", "# #", "###"],
        "9": ["###", "# #", "###", "  #", "###"],
        ":": [" ", "#", " ", "#", " "]
    })

    spacing: px

    Repeater {
        model: root.text.split("")

        Grid {
            id: glyph

            required property string modelData
            readonly property var rows: root.glyphs[modelData] ?? root.glyphs["0"]

            columns: rows[0].length

            Repeater {
                model: glyph.rows.join("").split("")

                Rectangle {
                    required property string modelData
                    width: root.px * 2   // «пиксель» вдвое шире, как ██ в терминале
                    height: root.px
                    color: modelData === "#" ? root.color : "transparent"
                }
            }
        }
    }
}
