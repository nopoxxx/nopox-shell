import Quickshell
import QtQuick
import qs.services

ShellRoot {
    // синглтоны создаются при первом обращении — проверка обновлений должна работать,
    // даже если модуль nopox ↑ убран с панели
    readonly property var _shellUpdate: ShellUpdate
    readonly property var _binds: Binds   // пишет nopox/keys.kdl при старте
    readonly property var _appTheme: AppTheme   // темы GTK и Qt вслед за shell

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
    GreeterSync {}
    DisplaysWindow {}
    BindsWindow {}
}
