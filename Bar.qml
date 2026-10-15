import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.services

// Панель в виде строки shell:
//   PS1 + «команда» (активное окно) слева, RPROMPT (метрики, время) справа
PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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
        T { text: " ❯ "; color: Theme.yellow; font.bold: true }

        T {
            visible: Niri.focusedWindow !== null
            text: Niri.focusedWindow?.app_id ?? ""
            color: Theme.fg
        }
        T {
            visible: Niri.focusedWindow !== null
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: "  # " + (Niri.focusedWindow?.title ?? "")
            color: Theme.gray
            elide: Text.ElideRight
        }

        // мигающий курсор, когда «команды» нет
        T {
            id: cursor
            visible: Niri.focusedWindow === null
            text: "█"
            color: Theme.fg
            Timer {
                interval: 530
                running: cursor.visible
                repeat: true
                onTriggered: cursor.opacity = cursor.opacity > 0 ? 0 : 1
            }
        }
        Item { visible: Niri.focusedWindow === null; Layout.fillWidth: true }
    }

    // ── RPROMPT ────────────────────────────────────────────────────
    Row {
        id: rprompt
        anchors {
            right: parent.right
            rightMargin: Theme.pad
            verticalCenter: parent.verticalCenter
        }

        T { text: "cpu "; color: Theme.gray }
        T {
            text: Sys.cpu + "%"
            color: Sys.cpu > 80 ? Theme.red : Sys.cpu > 50 ? Theme.yellow : Theme.fg
        }
        T { text: " · "; color: Theme.bg2 }
        T { text: "mem "; color: Theme.gray }
        T {
            text: Sys.memUsed.toFixed(1) + "G"
            color: Sys.memUsed / Sys.memTotal > 0.85 ? Theme.red : Theme.fg
        }
        T { text: " · "; color: Theme.bg2 }
        T { text: Niri.layout; color: Theme.purple }
        T { text: " · "; color: Theme.bg2 }
        T { text: Qt.formatDateTime(clock.date, "HH:mm"); color: Theme.orange; font.bold: true }
    }
}
