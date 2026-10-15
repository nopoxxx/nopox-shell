import Quickshell
import QtQuick
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens
        Background {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Settings.get("shell.bar.monitors") === "primary" ? [Quickshell.screens[0]] : Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Launcher {}
    WallPicker {}
    SettingsWindow {}
    NotifPopups {}
    LockScreen {}
}
