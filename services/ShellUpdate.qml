pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Обновления самого nopox-shell: если папка конфига — git-клон, периодически делает
// `git fetch` и сравнивает с upstream; update() — `git pull --ff-only` и перезапуск shell.
// Для приватного репозитория git должен уметь авторизоваться (например, `gh auth setup-git`).
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir
    property bool isRepo: false
    property bool checking: false
    property bool updating: false
    property bool dirty: false          // локальные правки — pull может не пройти
    property string upstream: ""
    property var commits: []            // [{ hash, subject }] — новые в upstream
    readonly property int behind: commits.length
    property string error: ""
    property bool updated: false        // уже обновились в этом запуске — напомнить про greeter
    readonly property bool greeterInstalled: greeterCheck.text().length > 0

    // force — проверить, даже если автопроверка выключена в настройках
    function check(force) {
        if (checker.running || updating) return;
        if (!force && !Settings.get("shell.update.check")) return;
        checking = true;
        checker.running = true;
    }

    function update() {
        if (updater.running || behind === 0) return;
        updating = true;
        error = "";
        updater.running = true;
    }

    // перезапуск через отвязанный процесс: он переживёт выход самого quickshell.
    // Уведомление — уже новому shell: старый вместе с историей уведомлений закрывается.
    function restartShell(title, body) {
        Quickshell.execDetached(["sh", "-c",
            'sleep 0.5; pkill -x qs; sleep 0.5; niri msg action spawn -- qs; sleep 3; [ -n "$1" ] && notify-send -a nopox-shell "$1" "$2"',
            "sh", title ?? "", body ?? ""]);
    }

    function updateGreeter() {
        Quickshell.execDetached(["kitty", "--class", "nopox-term", "--hold", "-e",
            "sudo", dir + "/extras/install-greeter.sh"]);
    }

    // файл-маркер: greeter установлен из этого shell
    FileView {
        id: greeterCheck
        path: "/usr/share/nopox-shell/greeter.qml"
        printErrors: false
    }

    Process {
        id: checker
        command: ["sh", "-c", `
            cd "$1" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo NOREPO; exit 0; }
            up=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || { echo NOUPSTREAM; exit 0; }
            GIT_TERMINAL_PROMPT=0 git fetch --quiet 2>/tmp/nopox-shell-fetch.$$ || { echo "FETCHFAIL $(tail -1 /tmp/nopox-shell-fetch.$$)"; rm -f /tmp/nopox-shell-fetch.$$; exit 0; }
            rm -f /tmp/nopox-shell-fetch.$$
            echo "UP $up"
            [ -n "$(git status --porcelain --untracked-files=no)" ] && echo DIRTY
            git log --format='C %h%x09%s' "HEAD..$up"`,
            "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const prev = root.behind;
                const commits = [];
                root.isRepo = true;
                root.dirty = false;
                root.error = "";
                for (const line of this.text.split("\n")) {
                    if (line === "NOREPO") root.isRepo = false;
                    else if (line === "NOUPSTREAM") root.error = "у ветки нет upstream";
                    else if (line.startsWith("FETCHFAIL")) root.error = "git fetch: " + line.slice(10);
                    else if (line.startsWith("UP ")) root.upstream = line.slice(3);
                    else if (line === "DIRTY") root.dirty = true;
                    else if (line.startsWith("C ")) {
                        const [hash, subject] = line.slice(2).split("\t");
                        commits.push({ hash, subject });
                    }
                }
                root.commits = commits;
                root.checking = false;
                if (prev === 0 && commits.length > 0 && Settings.get("shell.update.notify"))
                    Quickshell.execDetached(["notify-send", "-a", "nopox-shell", "Доступно обновление nopox-shell",
                        commits.length + " новых коммитов в " + root.upstream + " — клик по nopox ↑ на панели"]);
            }
        }
    }

    Process {
        id: updater
        command: ["sh", "-c", 'cd "$1" && GIT_TERMINAL_PROMPT=0 git pull --ff-only --quiet 2>&1', "sh", root.dir]
        stdout: StdioCollector { id: pullOut }
        onExited: code => {
            root.updating = false;
            if (code !== 0) {
                root.error = "git pull: " + (pullOut.text.trim().split("\n").pop() || "код " + code);
                return;
            }
            root.commits = [];
            root.updated = true;
            root.restartShell("nopox-shell обновлён",
                root.greeterInstalled ? "Greeter обновляется отдельно: setup/ → greeter update" : "");
        }
    }

    // первая проверка — через минуту после запуска, дальше по расписанию
    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: root.check()
    }

    Timer {
        interval: Settings.get("shell.update.hours") * 3600 * 1000
        running: Settings.get("shell.update.check")
        repeat: true
        onTriggered: root.check()
    }
}
