import QtQuick
import qs
import qs.services

// ~/ws/{1,[2],3} — как раскрытие скобок в shell.
// Показаны столы с окнами и активный; клик — перейти, колёсико — листать.
Item {
    id: root

    property var bar
    property bool available: true

    readonly property string output: bar?.screen?.name ?? ""
    readonly property var wsList: {
        const l = Niri.workspaces.filter(w => w.output === output);
        return l.length ? l : Niri.workspaces;
    }
    readonly property var shown: wsList.filter(w => w.is_active || w.is_urgent || Niri.windowsOn(w.id).length > 0)
    readonly property bool braces: shown.length > 1

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Niri.action(wheel.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
    }

    Row {
        id: row

        T { text: "~/ws/"; color: Theme.blue }
        T { visible: root.braces; text: "{"; color: Theme.gray }

        Repeater {
            model: root.shown

            Row {
                id: ws

                required property var modelData
                required property int index
                readonly property string name: modelData.name ?? String(modelData.idx)

                T { visible: ws.index > 0; text: ","; color: Theme.gray }
                T {
                    text: ws.modelData.is_active && root.braces ? "[" + ws.name + "]" : ws.name
                    color: ws.modelData.is_urgent ? Theme.red : ws.modelData.is_active ? Theme.accent : Theme.blue
                    font.bold: ws.modelData.is_active

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Niri.focusWorkspace(ws.modelData)
                    }
                }
            }
        }

        T { visible: root.braces; text: "}"; color: Theme.gray }
        T { visible: Niri.overview; text: " (overview)"; color: Theme.purple }
    }
}
