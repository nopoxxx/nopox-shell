import QtQuick

// Базовый текст: моноширинный шрифт и цвет по умолчанию
Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    color: Theme.fg
    renderType: Text.NativeRendering
}
