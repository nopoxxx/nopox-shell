pragma Singleton
import Quickshell
import QtQuick

// Gruvbox dark (hard) — единая палитра nopox-os
Singleton {
    readonly property color bg: "#1d2021"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color fg: "#ebdbb2"
    readonly property color gray: "#928374"
    readonly property color red: "#fb4934"
    readonly property color green: "#b8bb26"
    readonly property color yellow: "#fabd2f"
    readonly property color blue: "#83a598"
    readonly property color purple: "#d3869b"
    readonly property color aqua: "#8ec07c"
    readonly property color orange: "#fe8019"

    readonly property string font: "Terminess Nerd Font Mono"
    readonly property int fontSize: 16
    readonly property int barHeight: 26
    readonly property int pad: 10
}
