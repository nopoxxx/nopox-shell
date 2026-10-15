import Quickshell.Services.UPower
import QtQuick
import qs
import qs.bar

// bat 87%↑ — только если есть батарея ноутбука
Seg {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property real raw: dev?.percentage ?? 0
    readonly property int pct: Math.round(raw <= 1 ? raw * 100 : raw)
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
        || dev?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: dev?.state === UPowerDeviceState.FullyCharged

    available: dev?.isLaptopBattery ?? false
    label: "bat"
    value: pct + "%" + (charging ? "↑" : full ? "" : "↓")
    valueColor: charging || full ? Theme.green : pct < 15 ? Theme.red : pct < 30 ? Theme.yellow : Theme.fg
}
