pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Яркость подсветки экрана (/sys/class/backlight, первое устройство). Нет подсветки (десктоп) — available: false.
// Изменения извне (клавиши → brightnessctl) inotify в sysfs не видит — читаем раз в 400 мс.
Singleton {
    id: root

    property string dev: ""
    property int max: 0
    property int raw: -1
    readonly property bool available: dev !== "" && max > 0
    readonly property real value: available && raw >= 0 ? raw / max : 0

    function set(v) {
        if (!available) return;
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "--device=" + dev, "set", pct + "%"]);
        raw = Math.round(max * pct / 100);   // сразу, не дожидаясь опроса: ползунок не прыгает
    }

    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -r "$d/max_brightness" ] && { echo "${d##*/} $(cat "$d/max_brightness")"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, max] = this.text.trim().split(" ");
                if (!dev) return;
                root.max = Number(max);
                root.dev = dev;
            }
        }
    }

    FileView {
        id: file
        path: root.dev ? "/sys/class/backlight/" + root.dev + "/actual_brightness" : ""
        onLoaded: root.raw = parseInt(text())
    }

    Timer {
        interval: 400
        running: root.available
        repeat: true
        onTriggered: file.reload()
    }
}
