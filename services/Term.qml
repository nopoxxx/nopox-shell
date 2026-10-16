pragma Singleton
import Quickshell
import QtQuick
import "settings.js" as S

// Выбранный терминал (настройка shell.terminal) и команды запуска для него.
//   Term.open(["btop"])                         — обычное окно
//   Term.float(["paru", "-Syu"], { hold: true }) — плавающее окно nopox-term по центру (правило в window-rules.kdl);
//                                                 hold — окно не закрывается после команды
//   Term.edit(path)                             — открыть файл или папку в vim в плавающем окне
Singleton {
    id: root

    readonly property string name: Settings.get("shell.terminal")

    // конфиг выбранного терминала — для «system/ → конфиги → терминал»
    readonly property string configPath: Quickshell.env("HOME") + ({
        kitty: "/.config/kitty/kitty.conf",
        alacritty: "/.config/alacritty/alacritty.toml",
        ghostty: "/.config/ghostty/config",
        foot: "/.config/foot/foot.ini"
    })[name]

    function cmd(argv, opts) { return S.termCmd(name, argv, opts); }
    function open(argv) { Quickshell.execDetached(cmd(argv)); }
    function float(argv, opts) { Quickshell.execDetached(cmd(argv, Object.assign({ cls: "nopox-term" }, opts ?? {}))); }
    function edit(path) { float(["vim", path]); }
}
