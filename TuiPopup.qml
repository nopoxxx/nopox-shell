import Quickshell
import QtQuick
import QtQuick.Layouts

// Всплывающее окно в TUI-рамке под (или над) модулем панели.
// Закрывается кликом мимо него (grabFocus).
PopupWindow {
    id: pop

    property Item owner
    property var bar
    property string title: ""
    property bool open: false
    default property alias content: inner.data

    visible: open
    grabFocus: true
    color: "transparent"
    implicitWidth: frame.width
    implicitHeight: frame.y + frame.height

    anchor.window: bar
    anchor.edges: bar && bar.onTop ? Edges.Bottom : Edges.Top
    anchor.gravity: bar && bar.onTop ? Edges.Bottom : Edges.Top

    function show() {
        const p = owner.mapToItem(null, 0, 0);
        anchor.rect.x = p.x;
        anchor.rect.width = owner.width;
        anchor.rect.y = bar.onTop ? bar.height : 0;
        anchor.rect.height = 1;
        open = true;
    }

    function toggle() {
        if (open) open = false;
        else show();
    }

    onVisibleChanged: {
        if (!visible) open = false;
        if (bar) bar.openPopups = Math.max(0, bar.openPopups + (visible ? 1 : -1));
    }

    Rectangle {
        id: frame

        y: titleBox.height / 2
        width: inner.implicitWidth + Theme.pad * 2
        height: inner.implicitHeight + Theme.pad * 2 + titleBox.height / 2
        color: Theme.bg
        border.color: Theme.accent
        border.width: 2

        ColumnLayout {
            id: inner
            x: Theme.pad
            y: Theme.pad + titleBox.height / 2
            spacing: 2
        }
    }

    // заголовок на линии рамки: ┌─[ cal ]────
    Rectangle {
        id: titleBox

        visible: pop.title !== ""
        x: Theme.pad
        width: titleText.implicitWidth
        height: titleText.implicitHeight
        color: Theme.bg

        T { id: titleText; text: "[ " + pop.title + " ]"; color: Theme.accent; font.bold: true }
    }
}
