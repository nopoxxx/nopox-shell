import Quickshell
import QtQuick
import qs.services
import "services/settings.js" as S

// Модульная панель: три зоны — left, center, right.
// Состав и порядок модулей — в настройках (Mod+S → bar/), сами модули — в bar/
PanelWindow {
    id: bar

    readonly property bool onTop: Settings.get("shell.bar.position") === "top"
    readonly property bool floating: Settings.get("shell.bar.style") === "floating"
    readonly property bool autohide: Settings.get("shell.bar.autohide")
    readonly property string separator: Settings.get("shell.bar.separator")
    readonly property var layout: S.normalizeLayout(Settings.get("shell.bar.layout"))
    readonly property real opacityPct: Settings.get("shell.bar.opacity") / 100
    readonly property int gap: floating ? 8 : 0
    readonly property int fullHeight: Theme.barHeight + (floating ? 4 : 0)

    // открытые попапы держат панель видимой при автоскрытии
    property int openPopups: 0
    readonly property bool revealed: !autohide || hover.hovered || openPopups > 0

    anchors { top: onTop; bottom: !onTop; left: true; right: true }
    margins { top: onTop ? gap : 0; bottom: onTop ? 0 : gap; left: gap; right: gap }
    // при автоскрытии остаётся полоска в 4px, наведение на неё показывает панель
    implicitHeight: revealed ? fullHeight : 4
    exclusionMode: autohide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        visible: bar.revealed
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bar.opacityPct)
        border.width: bar.floating ? 2 : 0
        border.color: Theme.accent

        BarZone {
            bar: bar
            ids: bar.layout.left
            anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        }

        BarZone {
            bar: bar
            ids: bar.layout.center
            anchors.centerIn: parent
        }

        BarZone {
            bar: bar
            ids: bar.layout.right
            anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        }
    }
}
