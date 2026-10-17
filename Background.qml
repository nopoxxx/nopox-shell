import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services

// Обои на нижнем слое layer-shell; новая картинка проявляется поверх старой
PanelWindow {
    id: bg

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ochre-wallpaper"
    color: "#282828"   // виден по краям в режиме fit

    readonly property string src: Wallpaper.current ? "file://" + encodeURI(Wallpaper.current) : ""
    readonly property int mode: Wallpaper.fill === "fit" ? Image.PreserveAspectFit
        : Wallpaper.fill === "stretch" ? Image.Stretch
        : Image.PreserveAspectCrop

    onSrcChanged: {
        prev.source = cur.source;
        cur.opacity = 0;
        cur.source = src;
    }

    Image {
        id: prev
        anchors.fill: parent
        fillMode: bg.mode
        asynchronous: true
    }

    Image {
        id: cur

        anchors.fill: parent
        fillMode: bg.mode
        asynchronous: true
        opacity: 0
        source: bg.src
        onStatusChanged: if (status === Image.Ready) fade.restart()

        NumberAnimation on opacity {
            id: fade
            running: false
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
            // иначе в режиме fit старая картинка торчала бы из-под новой по краям
            onFinished: prev.source = ""
        }
    }
}
