import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import "../services/glyphs.js" as G

// Батарея (только ноутбук) и профиль питания power-profiles-daemon: ←→ — выбор, ↵ — включить.
// Нет ни батареи, ни демона — секции не видно.
Section {
    id: sec

    title: "питание"

    property bool ppd: false
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat?.isLaptopBattery ?? false
    readonly property real pct: hasBat ? (bat.percentage <= 1 ? bat.percentage : bat.percentage / 100) : 0
    readonly property bool charging: hasBat && (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.PendingCharge)

    readonly property var profiles: !ppd ? [] : [
        { p: PowerProfile.PowerSaver, icon: G.g("saver"), text: "эконом" },
        { p: PowerProfile.Balanced, icon: G.g("balanced"), text: "баланс" }
    ].concat(PowerProfiles.hasPerformanceProfile ? [{ p: PowerProfile.Performance, icon: G.g("performance"), text: "мощность" }] : [])

    available: hasBat || ppd
    count: profiles.length

    function key(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) cur = Math.max(0, cur - 1);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) cur = Math.min(count - 1, cur + 1);
        else return false;
        return true;
    }

    function activate(i) { if (profiles[i]) PowerProfiles.profile = profiles[i].p; }

    function fmtTime(s) {
        if (!(s > 0)) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return (h ? h + "ч " : "") + m + "м";
    }

    Process {
        command: ["powerprofilesctl", "get"]
        running: true
        onExited: code => sec.ppd = code === 0
    }

    RowLayout {
        visible: sec.hasBat
        spacing: 0
        T { font.family: Theme.iconFont; text: G.g(sec.charging ? "charging" : "battery") + " "; color: sec.charging ? Theme.green : Theme.accent }
        T {
            readonly property int n: 20
            readonly property int f: Math.round(sec.pct * n)
            text: "▕" + "█".repeat(f) + "░".repeat(n - f) + "▏ "
            color: sec.charging ? Theme.green : sec.pct < 0.15 ? Theme.red : sec.pct < 0.3 ? Theme.yellow : Theme.accent
        }
        T {
            text: Math.round(sec.pct * 100) + "%"
                + (sec.charging ? (sec.bat.timeToFull > 0 ? " · до полной " + sec.fmtTime(sec.bat.timeToFull) : "")
                                : (sec.bat?.timeToEmpty > 0 ? " · осталось " + sec.fmtTime(sec.bat.timeToEmpty) : ""))
            color: Theme.fg
        }
    }

    Row {
        visible: sec.profiles.length > 0
        spacing: sec.panel.cell.advanceWidth
        Repeater {
            model: sec.profiles
            Btn {
                required property var modelData
                required property int index
                icon: modelData.icon
                text: modelData.text
                on: PowerProfiles.profile === modelData.p
                current: sec.isCur(index)
                onClicked: { sec.pick(index); sec.activate(index); }
            }
        }
    }
}
