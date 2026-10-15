import QtQuick

// Мигающий блочный курсор █, как в терминале. Пока виден — мигает, при показе — сразу видимый.
T {
    id: cur

    text: "█"
    color: Theme.fg

    Timer {
        interval: 530
        running: cur.visible
        repeat: true
        onTriggered: cur.opacity = cur.opacity > 0 ? 0 : 1
        onRunningChanged: cur.opacity = 1
    }
}
