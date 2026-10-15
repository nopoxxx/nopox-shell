import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services

// Панель в виде строки shell:
//   PS1 + «команда» (активное окно) слева, RPROMPT (метрики, время) справа
PanelWindow {
    id: bar

    readonly property bool onTop: Settings.get("shell.bar.position") === "top"
    readonly property string clockFormat: Settings.get("shell.bar.clock")
    readonly property bool showTitle: Settings.get("shell.bar.title") && Niri.focusedWindow !== null

    anchors { top: onTop; bottom: !onTop; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    SystemClock {
        id: clock
        precision: bar.clockFormat.includes("ss") ? SystemClock.Seconds : SystemClock.Minutes
    }

    // сегменты RPROMPT, которые включены в настройках
    readonly property var segments: {
        const s = [];
        if (Settings.get("shell.bar.cpu"))
            s.push({ label: "cpu", value: Sys.cpu + "%", color: Sys.cpu > 80 ? Theme.red : Sys.cpu > 50 ? Theme.yellow : Theme.fg });
        if (Settings.get("shell.bar.mem"))
            s.push({ label: "mem", value: Sys.memUsed.toFixed(1) + "G", color: Sys.memUsed / Sys.memTotal > 0.85 ? Theme.red : Theme.fg });
        if (Settings.get("shell.bar.layout"))
            s.push({ value: Niri.layout, color: Theme.purple });
        s.push({ value: Qt.formatDateTime(clock.date, clockFormat), color: Theme.orange, bold: true });
        return s;
    }

    // ── PS1 + команда ──────────────────────────────────────────────
    RowLayout {
        anchors {
            left: parent.left
            right: rprompt.left
            leftMargin: Theme.pad
            rightMargin: Theme.pad * 2
            verticalCenter: parent.verticalCenter
        }
        spacing: 0

        T { text: Sys.user; color: Theme.green; font.bold: true }
        T { text: "@"; color: Theme.gray }
        T { text: Sys.host; color: Theme.aqua; font.bold: true }
        T { text: " ~/ws/" + (Niri.focusedWorkspace?.name ?? Niri.focusedWorkspace?.idx ?? "?"); color: Theme.blue }
        T { text: " ❯ "; color: Theme.accent; font.bold: true }

        T {
            visible: bar.showTitle
            text: Niri.focusedWindow?.app_id ?? ""
            color: Theme.fg
        }
        T {
            visible: bar.showTitle
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "  # " + (Niri.focusedWindow?.title ?? "")
            color: Theme.gray
            elide: Text.ElideRight
        }

        // мигающий курсор, когда «команды» нет
        T {
            id: cursor
            visible: !bar.showTitle
            text: "█"
            color: Theme.fg
            Timer {
                interval: 530
                running: cursor.visible
                repeat: true
                onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1
            }
        }
        Item { visible: !bar.showTitle; Layout.fillWidth: true }
    }

    // ── RPROMPT ────────────────────────────────────────────────────
    Row {
        id: rprompt
        anchors {
            right: parent.right
            rightMargin: Theme.pad
            verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: bar.segments

            Row {
                required property var modelData
                required property int index

                T { visible: index > 0; text: " · "; color: Theme.bg2 }
                T { visible: !!modelData.label; text: (modelData.label ?? "") + " "; color: Theme.gray }
                T { text: modelData.value; color: modelData.color; font.bold: !!modelData.bold }
            }
        }
    }
}
