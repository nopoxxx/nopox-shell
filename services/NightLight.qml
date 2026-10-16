pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Ночной режим: gammastep держит тёплые цвета, пока запущен (под Wayland -O не выходит сразу).
// shell.night.on — включён ли, shell.night.temp — температура, shell.night.auto — только от заката
// до рассвета в месте погоды (Weather.place). Нет gammastep — available: false.
Singleton {
    id: root

    property bool available: false
    readonly property bool on: Settings.get("shell.night.on")
    readonly property int temp: Settings.get("shell.night.temp")
    readonly property bool auto: Settings.get("shell.night.auto")
    readonly property var place: auto ? Weather.place : null
    readonly property bool wanted: available && on && !Settings.greeterMode && (!auto || place !== null)

    readonly property var args: auto && place
        ? ["-l", place.lat.toFixed(2) + ":" + place.lon.toFixed(2), "-t", "6500:" + temp]
        : ["-O", String(temp)]

    function toggle() { Settings.set("shell.night.on", !on); }

    Process {
        command: ["sh", "-c", "command -v gammastep"]
        running: true
        onExited: code => root.available = code === 0
    }

    // смена параметров: остановить и запустить заново чуть позже — перезапуск в том же такте Process пропустил бы
    onArgsChanged: restart()
    onWantedChanged: restart()

    function restart() {
        proc.running = false;
        if (wanted) delay.restart();
    }

    Timer { id: delay; interval: 300; onTriggered: proc.running = root.wanted }

    Process {
        id: proc
        // qs при выходе по сигналу детей не убивает — сначала гасим gammastep прошлого запуска
        command: ["sh", "-c", 'pkill -u "$(id -u)" -x gammastep; exec gammastep -m wayland -P "$@"', "sh", ...root.args]
    }
}
