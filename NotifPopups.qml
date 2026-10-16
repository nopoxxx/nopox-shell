import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Стопка всплывающих уведомлений в углу экрана с фокусом.
// exclusiveZone 0 — окно обходит панель, а не ложится под неё.
PanelWindow {
    id: win

    readonly property string position: Settings.get("shell.notify.position")
    readonly property bool atTop: position.startsWith("top")
    readonly property bool atRight: position.endsWith("right")

    screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? Quickshell.screens[0]
    visible: Notifs.popups.count > 0 && !Notifs.centerOpen
    anchors { top: atTop; bottom: !atTop; right: atRight; left: !atRight }
    margins { top: 8; bottom: 8; left: 8; right: 8 }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nopox-notify"
    color: "transparent"
    implicitWidth: col.implicitWidth
    implicitHeight: Math.max(1, col.implicitHeight)

    Column {
        id: col
        spacing: 8

        // ушедшая карточка — остальные съезжают на её место, а не прыгают
        move: Transition {
            enabled: Settings.get("shell.notify.anim") !== "none"
            NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: Notifs.popups
            NotifCard {}
        }
    }
}
