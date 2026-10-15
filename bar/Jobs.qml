import QtQuick
import qs
import qs.services

// [3] — окна на активном столе этого монитора, как `jobs` в shell
Item {
    id: root

    property var bar

    readonly property string output: bar?.screen?.name ?? ""
    readonly property var ws: Niri.workspaces.find(w => w.output === output && w.is_active) ?? Niri.focusedWorkspace
    readonly property int count: ws ? Niri.windowsOn(ws.id).length : 0
    property bool available: count > 0

    implicitWidth: t.implicitWidth
    implicitHeight: t.implicitHeight

    T { id: t; text: "[" + root.count + "]"; color: Theme.purple }
}
